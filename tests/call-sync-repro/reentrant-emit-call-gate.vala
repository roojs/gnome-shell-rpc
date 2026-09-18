/**
 * Gate: a **synchronous** {@code call_poll} issued from **inside** a
 * {@code Live.Invoke} handler — while the server is still blocked in
 * {@code hook.emit} — must complete without deadlock.
 *
 * This is the live "hang after settle" shape reduced to two real-libocrpc
 * processes (no Clutter / stubs / generator). In the product, a GJS signal /
 * vfunc / notification handler runs during a server {@code hook.emit} (vfunc
 * relay) and then makes a blocking RPC back to the server, e.g.:
 *   - {@code Clutter.get_current_event} (`Clutter.override` → `Clutter.vala`)
 *   - {@code Meta-Workspace.set_builtin_struts} then emit `workareas-changed`
 *     (`Workspace.override`) whose handler relayouts + calls back
 *   - generic `default` re-emit (`Runtime.vala`) driving another sync call
 *
 * Shape:
 *   server Gate.provoke → hook.emit(A)            (server blocked in emit)
 *   client INVOKE handler → call_poll(Gate.ping)  (nested SYNC request)
 *                         → server must dispatch ping WHILE in emit
 *                         → then RPC-Live-Callback.reply
 *   server emit(A) returns → Gate.provoke replies
 *
 *   meson compile -C build reentrant-emit-call-gate
 *   timeout 8 ./build/tests/call-sync-repro/reentrant-emit-call-gate
 *
 * PASS → OPC dispatches a nested request during emit; the re-entrant sync
 *        call is safe at the transport → the live hang is a **consumer**
 *        timing/re-entrancy chase (defer the emit/round-trip out of the
 *        handler).
 * FAIL (timeout) → OPC cannot service a request while a Hook.emit is in
 *        flight → cross-process re-entrant sync-RPC deadlock. File in
 *        OLLMchat; do not edit OLLMchat from this tree; keep this FAIL gate.
 */

class Gate : GLib.Object
{
	public static OLLMrpc.Live.Hook? held_hook;
	public static bool ping_seen_during_emit = false;
	public static bool in_emit = false;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"provoke", "t",
			"ping", "",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	/**
	 * Emit the callback and block in emit until the client replies. The
	 * client's Invoke handler will issue a nested {@code Gate.ping} first;
	 * the server must dispatch it while {@code in_emit} is true.
	 */
	public void provoke(OLLMrpc.Request request, uint64 callback_id)
	{
		var id = (int) callback_id;
		if (!request.connection.callbacks.has_key(id)) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var hook = request.connection.callbacks.get(id);
		Gate.held_hook = hook;

		stderr.printf("server: provoke → hook.emit BEGIN\n");
		stderr.flush();
		Gate.in_emit = true;
		hook.emit(new Gee.ArrayList<GLib.Value?>());
		Gate.in_emit = false;
		stderr.printf("server: hook.emit END replied=%s ping_during_emit=%s\n",
			hook.replied.to_string(),
			Gate.ping_seen_during_emit.to_string());
		stderr.flush();

		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}

	/**
	 * Normal server method the client calls **re-entrantly** from inside
	 * its Invoke handler. If dispatched while {@code in_emit}, that is the
	 * re-entrant path we need to prove safe.
	 */
	public void ping(OLLMrpc.Request request)
	{
		if (Gate.in_emit) {
			Gate.ping_seen_during_emit = true;
		}
		stderr.printf("server: ping (in_emit=%s)\n", Gate.in_emit.to_string());
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("i", 42),
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
		stderr.printf("FAIL reentrant-emit-call-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-reentrant-emit-call-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL reentrant-emit-call-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL reentrant-emit-call-gate: server socket never appeared\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 3,
	};

	int ping_result = 0;
	string ping_err = "";
	client.invoke.connect((call) => {
		stderr.printf("client: INVOKE id=%d reply_id=%d\n",
			call.id, call.reply_id);
		stderr.flush();
		/*
		 * Re-entrant SYNC call back to the server WHILE the server is
		 * still inside hook.emit — the live handler-issues-RPC shape.
		 */
		try {
			var pong = client.call_poll(new OLLMrpc.Request() {
				method = "Gate.ping",
			});
			ping_result = pong.args.get(0).get_int();
			stderr.printf("client: nested Gate.ping → %d\n", ping_result);
			stderr.flush();
		} catch (Error e) {
			ping_err = e.message;
			stderr.printf("client: nested Gate.ping ERR %s\n", e.message);
			stderr.flush();
		}
		/* Now release the emit. */
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
		args = OLLMrpc.args("is", 1, "reentrant-emit-call-gate"),
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
		stderr.printf("FAIL reentrant-emit-call-gate: connect %s\n", connect_err);
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
		stderr.printf("FAIL reentrant-emit-call-gate: register %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}
	stderr.printf("client: callback id=%llu\n", cb_id);
	stderr.flush();

	string provoke_err = "";
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.provoke",
			args = OLLMrpc.args("t", cb_id),
		});
	} catch (Error e) {
		provoke_err = e.message;
		stderr.printf("client: provoke ERR %s\n", e.message);
		stderr.flush();
	}

	server.force_exit();
	FileUtils.unlink(sock);

	if (provoke_err != "") {
		stderr.printf(
			"FAIL reentrant-emit-call-gate: provoke %s\n"
			+ "  shape: nested sync call_poll inside Live.Invoke while server in hook.emit → deadlock\n",
			provoke_err);
		stderr.flush();
		return 1;
	}
	if (ping_err != "") {
		stderr.printf(
			"FAIL reentrant-emit-call-gate: nested ping %s\n"
			+ "  shape: server did not dispatch a request while in hook.emit\n",
			ping_err);
		stderr.flush();
		return 1;
	}
	if (ping_result != 42) {
		stderr.printf(
			"FAIL reentrant-emit-call-gate: nested ping result %d want 42\n",
			ping_result);
		stderr.flush();
		return 1;
	}
	stderr.printf(
		"PASS reentrant-emit-call-gate: nested sync call during hook.emit ok (ping=42)\n");
	stderr.flush();
	return 0;
}
