/**
 * Gate: Response and Live.Invoke back-to-back on the wire before the client
 * finishes call_poll — does buffered Invoke reach the client with only
 * MainContext pumping (no further outbound RPC)?
 *
 * Differs from after-reply-gate: no prior emit A (that race lets Invoke B
 * arrive as a later POLLIN). Here reply + emit are the first bytes the
 * client reads for this call — Invoke can sit in DataInputStream while
 * poll_drain_readable only checks IOChannel IN (Weston-after-READY shape).
 *
 * Two processes — not a server thread. No OPC edits from this tree.
 *
 *   meson compile -C build buffer-invoke-gate
 *   timeout 5 ./build/tests/call-sync-repro/buffer-invoke-gate
 *
 * PASS → chase consumer.
 * FAIL → file OPC with this output (drain bin.get_available() in
 *        poll_drain_readable / before poll(-1)).
 */

class Gate : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"fire", "t",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	/**
	 * Write Response then Hook.emit in the same dispatch turn so both
	 * messages can share one client read buffer.
	 */
	public void fire(OLLMrpc.Request request, uint64 callback_id)
	{
		var id = (int) callback_id;
		if (!request.connection.callbacks.has_key(id)) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var hook = request.connection.callbacks.get(id);

		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
		stderr.printf("server: Response written, emit BEGIN\n");
		stderr.flush();
		hook.emit(new Gee.ArrayList<GLib.Value?>());
		stderr.printf("server: emit END replied=%s\n", hook.replied.to_string());
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
		stderr.printf("FAIL buffer-invoke-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-buffer-invoke-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL buffer-invoke-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL buffer-invoke-gate: server socket never appeared\n");
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
	client.invoke.connect((call) => {
		invoke_n++;
		stderr.printf("client: INVOKE #%d id=%d reply_id=%d\n",
			invoke_n, call.id, call.reply_id);
		stderr.flush();
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
		args = OLLMrpc.args("is", 1, "buffer-invoke-gate"),
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
		stderr.printf("FAIL buffer-invoke-gate: connect %s\n", connect_err);
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
		stderr.printf("FAIL buffer-invoke-gate: register %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}
	stderr.printf("client: callback id=%llu\n", cb_id);
	stderr.flush();

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.fire",
			args = OLLMrpc.args("t", cb_id),
		});
	} catch (Error e) {
		stderr.printf("FAIL buffer-invoke-gate: fire %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 1;
	}
	stderr.printf("client: fire returned (invoke_n=%d)\n", invoke_n);
	stderr.flush();

	bool timed_out = false;
	Timeout.add(2000, () => {
		timed_out = true;
		return Source.REMOVE;
	});
	while (invoke_n < 1 && !timed_out) {
		MainContext.default().iteration(true);
	}

	server.force_exit();
	FileUtils.unlink(sock);

	if (invoke_n >= 1) {
		stderr.printf(
			"PASS buffer-invoke-gate — Invoke seen (invoke_n=%d)\n",
			invoke_n);
		stderr.flush();
		return 0;
	}
	stderr.printf(
		"FAIL buffer-invoke-gate — Invoke never reached client (invoke_n=%d)\n",
		invoke_n);
	stderr.printf(
		"  shape: Response+Invoke same server turn; client only MainContext after call_poll\n");
	stderr.printf(
		"  suspect: Client.poll_drain_readable ignores Bin.Stream.get_available()\n");
	stderr.flush();
	return 1;
}
