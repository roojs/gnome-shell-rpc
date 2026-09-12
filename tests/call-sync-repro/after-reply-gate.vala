/**
 * Gate: Response then Live.Invoke in the same server turn — does the client
 * still see Invoke B after call_poll returns, with only MainContext pumping?
 *
 * Models Weston after READY: server finishes a reply, writes another
 * preferred_* Invoke; client call_poll may have already taken the Response.
 *
 * Two processes (mutter-rpc + shell-client shape) — not a server thread.
 *
 *   meson compile -C build after-reply-gate
 *   timeout 5 ./build/tests/call-sync-repro/after-reply-gate
 *
 * PASS → this shape is fine; chase consumer.
 * FAIL → solid repro for OPC (drain buffered Invoke on poll_close).
 */

class Gate : GLib.Object
{
	public static OLLMrpc.Live.Hook? held_hook;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"emit_once", "t",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	/**
	 * Emit A (client replies in-flow), reply to the request, then emit B
	 * in the same turn so Invoke B can share the read buffer with the
	 * Response — the Weston hang shape (not Idle-after-return).
	 */
	public void emit_once(OLLMrpc.Request request, uint64 callback_id)
	{
		var id = (int) callback_id;
		if (!request.connection.callbacks.has_key(id)) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var hook = request.connection.callbacks.get(id);
		Gate.held_hook = hook;

		stderr.printf("server: emit A BEGIN\n");
		stderr.flush();
		hook.emit(new Gee.ArrayList<GLib.Value?>());
		stderr.printf("server: emit A END replied=%s\n", hook.replied.to_string());
		stderr.flush();

		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});

		/* Same turn as Response: Invoke may land in client DataInputStream
		 * while call_poll is exiting — must be drained on poll_close. */
		stderr.printf("server: emit B BEGIN (post-Response same turn)\n");
		stderr.flush();
		hook.emit(new Gee.ArrayList<GLib.Value?>());
		stderr.printf("server: emit B END replied=%s\n", hook.replied.to_string());
		stderr.flush();
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
		stderr.printf("FAIL after-reply-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-after-reply-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL after-reply-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	/* Wait until the socket exists (server Listen.start). */
	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL after-reply-gate: server socket never appeared\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 3,
	};

	int invoke_n = 0;
	bool got_b = false;
	client.invoke.connect((call) => {
		invoke_n++;
		stderr.printf("client: INVOKE #%d id=%d reply_id=%d\n",
			invoke_n, call.id, call.reply_id);
		stderr.flush();
		if (invoke_n >= 2) {
			got_b = true;
		}
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "RPC-Live-Callback.reply",
				args = OLLMrpc.args("t", (uint64) call.reply_id),
			});
		} catch (Error e) {
			stderr.printf("client: reply ERR %s\n", e.message);
			stderr.flush();
		}
	});

	var loop = new MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "after-reply-gate"),
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
		stderr.printf("FAIL after-reply-gate: connect %s\n", connect_err);
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
		stderr.printf("FAIL after-reply-gate: register %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}
	stderr.printf("client: callback id=%llu\n", cb_id);
	stderr.flush();

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.emit_once",
			args = OLLMrpc.args("t", cb_id),
		});
	} catch (Error e) {
		stderr.printf("FAIL after-reply-gate: emit_once %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 1;
	}
	stderr.printf("client: emit_once returned (invoke_n=%d)\n", invoke_n);
	stderr.flush();

	/* Only pump default MainContext — no further outbound RPC. */
	bool timed_out = false;
	Timeout.add(2000, () => {
		timed_out = true;
		return Source.REMOVE;
	});
	while (!got_b && !timed_out) {
		MainContext.default().iteration(true);
	}

	server.force_exit();
	FileUtils.unlink(sock);

	if (got_b) {
		stderr.printf(
			"PASS after-reply-gate — Invoke B seen (invoke_n=%d)\n",
			invoke_n);
		stderr.flush();
		return 0;
	}
	stderr.printf(
		"FAIL after-reply-gate — Invoke B never reached client (invoke_n=%d)\n",
		invoke_n);
	stderr.printf(
		"  shape: Response then Hook.emit B same server turn; client only MainContext after call_poll\n");
	stderr.flush();
	return 1;
}
