/**
 * Gate: an **outer** synchronous {@code call_poll} whose **server** handler
 * emits a NEW {@code Live.Hook} mid-flight, so the client must send
 * {@code RPC-Live-Callback.reply} as a **nested** (poll-depth-2) call while the
 * outer request is still pending. The nested reply's Response must reach the
 * client — and then the outer call must complete.
 *
 * This is the depth-2 reduction of the live "hang after settle" deadlock
 * (2026-09-18). Paired backtraces at the freeze (docs/bugs/…-race.md) show:
 *
 *   client: call_poll(Meta-Workspace.get_work_area_for_monitor)   [OUTER]
 *             → poll_drain_readable → dispatch_message(INVOKE B)
 *               → Runtime invoke handler
 *                 → call_poll(RPC-Live-Callback.reply)             [NESTED]
 *                   → __poll   (blocked; the reply's Response never arrives)
 *   server: get_preferred_height → hook.emit → emit_wait_poll → __poll
 *             (blocked; waiting the client's reply to that emit)
 *
 *   The server HAD received the nested RPC-Live-Callback.reply (its log ends
 *   `recv … RPC-Live-Callback.reply`) but the client never saw a Response to
 *   it — the outer get_work_area reply and the nested reply's Response race in
 *   the same socket, and one is stranded.
 *
 * The existing {@code reentrant-emit-call-gate} nests the reply under the SAME
 * provoke call that triggered the emit (depth-1 relative to the emit). The live
 * hang nests the reply under a DIFFERENT outer sync call (get_work_area) —
 * that is what this gate adds.
 *
 *   meson compile -C build outer-emit-reply-gate
 *   timeout 8 ./build/tests/call-sync-repro/outer-emit-reply-gate
 *
 * PASS → OPC delivers the nested reply's Response and completes the outer call
 *        even with an emit interleaved → transport safe at depth-2 → the live
 *        hang is a **consumer** re-entrancy chase (stop issuing sync round-trips
 *        from invoke/notification handlers that run under another sync call).
 * FAIL (timeout) → OPC strands the nested Response / cannot complete the outer
 *        call across an interleaved emit → transport deadlock. File in OLLMchat
 *        docs/bugs/; do not edit OLLMchat from this tree; keep this FAIL gate.
 */

class Gate : GLib.Object
{
	public static bool in_emit = false;
	public static bool emit_replied = false;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"outer", "t",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	/**
	 * The OUTER sync method. Instead of replying straight away, emit the
	 * client callback and block in {@code hook.emit} until the client's
	 * nested {@code RPC-Live-Callback.reply} arrives. Only then reply to
	 * the outer request. This reproduces "server emits mid outer call".
	 */
	public void outer(OLLMrpc.Request request, uint64 callback_id)
	{
		var id = (int) callback_id;
		if (!request.connection.callbacks.has_key(id)) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var hook = request.connection.callbacks.get(id);

		stderr.printf("server: outer → hook.emit BEGIN (outer id=%d)\n",
			request.id);
		stderr.flush();
		Gate.in_emit = true;
		hook.emit(new Gee.ArrayList<GLib.Value?>());
		Gate.in_emit = false;
		Gate.emit_replied = hook.replied;
		stderr.printf("server: hook.emit END replied=%s → reply outer id=%d\n",
			hook.replied.to_string(), request.id);
		stderr.flush();

		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("i", 7),
		});
	}
}

static void boot_rpc()
{
	OLLMrpc.rpc_register(true);
	GnomeShellRpc.Rpc.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new GnomeShellRpc.Rpc.Daemon());
	Gate.rpc_register();
}

static int run_server(string sock)
{
	boot_rpc();
	var listen = new GnomeShellRpc.Rpc.Listen(sock) {
		live_handles = true,
	};
	if (!listen.start()) {
		stderr.printf("FAIL outer-emit-reply-gate server: listen %s\n", sock);
		stderr.flush();
		return 2;
	}
	stderr.printf("server: listening %s\n", sock);
	stderr.flush();
	new MainLoop().run();
	listen.stop();
	return 0;
}

static string self_exe(string argv0)
{
	try {
		return FileUtils.read_link("/proc/self/exe");
	} catch (FileError e) {
		return argv0;
	}
}

int main(string[] args)
{
	if (args.length >= 3 && args[1] == "server") {
		return run_server(args[2]);
	}

	var sock = "/tmp/gsr-outer-emit-reply-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL outer-emit-reply-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL outer-emit-reply-gate: server socket never appeared\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 3,
	};

	string reply_err = "";
	bool nested_reply_done = false;
	client.invoke.connect((call) => {
		stderr.printf("client: INVOKE id=%d reply_id=%d (nested reply under outer)\n",
			call.id, call.reply_id);
		stderr.flush();
		/*
		 * NESTED reply to the emit, issued WHILE the outer Gate.outer
		 * call_poll is still pending on this same thread (poll-depth 2).
		 */
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "RPC-Live-Callback.reply",
				args = OLLMrpc.args("t", (uint64) call.reply_id),
			});
			nested_reply_done = true;
			stderr.printf("client: nested RPC-Live-Callback.reply DONE\n");
			stderr.flush();
		} catch (Error e) {
			reply_err = e.message;
			stderr.printf("client: nested reply ERR %s\n", e.message);
			stderr.flush();
		}
	});

	var loop = new MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "outer-emit-reply-gate"),
	}, null, (obj, res) => {
		try {
			connected = client.connect.end(res);
			if (!connected) {
				connect_err = client.connect_error;
			}
		} catch (Error e) {
			connect_err = e.message;
		}
		loop.quit();
	});
	loop.run();
	if (!connected) {
		stderr.printf("FAIL outer-emit-reply-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	uint64 cb_id = 0;
	try {
		var reg = client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Callback.register",
		});
		cb_id = reg.args.get(0).get_uint64();
	} catch (Error e) {
		stderr.printf("FAIL outer-emit-reply-gate: register %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}
	stderr.printf("client: callback id=%llu\n", cb_id);
	stderr.flush();

	int outer_result = 0;
	string outer_err = "";
	try {
		var r = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.outer",
			args = OLLMrpc.args("t", cb_id),
		});
		if (r.args.size >= 1) {
			outer_result = r.args.get(0).get_int();
		}
	} catch (Error e) {
		outer_err = e.message;
		stderr.printf("client: outer ERR %s\n", e.message);
		stderr.flush();
	}

	server.force_exit();
	FileUtils.unlink(sock);

	if (outer_err != "") {
		stderr.printf(
			"FAIL outer-emit-reply-gate: outer %s\n"
			+ "  shape: outer sync call_poll pending; server emits mid-call;\n"
			+ "  client sends nested RPC-Live-Callback.reply (poll-depth 2);\n"
			+ "  nested Response / outer reply stranded → deadlock.\n",
			outer_err);
		stderr.flush();
		return 1;
	}
	if (reply_err != "") {
		stderr.printf(
			"FAIL outer-emit-reply-gate: nested reply %s\n", reply_err);
		stderr.flush();
		return 1;
	}
	if (!nested_reply_done) {
		stderr.printf("FAIL outer-emit-reply-gate: nested reply never completed\n");
		stderr.flush();
		return 1;
	}
	if (outer_result != 7) {
		stderr.printf(
			"FAIL outer-emit-reply-gate: outer result %d want 7\n", outer_result);
		stderr.flush();
		return 1;
	}
	stderr.printf(
		"PASS outer-emit-reply-gate: nested reply + outer completed across emit\n");
	stderr.flush();
	return 0;
}
