/**
 * Gate: client→server {@link OLLMrpc.Live.Buffer} on a {@link OLLMrpc.Request}.
 *
 * D2.2 {@code ImageContent.set_data} needs pixmap bytes via SCM_RIGHTS on
 * the call. {@code Client.call_poll} only {@code bin.write(request)} — no
 * outbound buffer — and {@code Request} has no {@code buffer} field.
 *
 *   meson compile -C build request-buffer-gate
 *   timeout 5 ./build/tests/call-sync-repro/request-buffer-gate
 *
 * FAIL → OPC: outbound Request + Live.Buffer (call_poll / write path) and
 * server attach before dispatch. No OPC edits from this tree.
 */

class Gate : GLib.Object
{
	public static bool saw_buffer = false;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"eat_fd", "x",
			null
		);
		OLLMrpc.Request.register("Gate", new Gate());
	}

	/**
	 * Would read pixels from request buffer if OPC attached one.
	 */
	public void eat_fd(OLLMrpc.Request request, int64 nbytes)
	{
		stderr.printf("server eat_fd nbytes=%lld saw_buffer=%s\n",
			nbytes, Gate.saw_buffer.to_string());
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("b", Gate.saw_buffer),
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
		stderr.printf("FAIL request-buffer-gate server: listen %s\n", sock);
		stderr.flush();
		return 2;
	}
	stderr.printf("server: listening %s\n", sock);
	stderr.flush();
	new GLib.MainLoop().run();
	listen.stop();
	return 0;
}

static string self_exe(string argv0)
{
	try {
		return GLib.FileUtils.read_link("/proc/self/exe");
	} catch (GLib.FileError e) {
		return argv0;
	}
}

int main(string[] args)
{
	if (args.length >= 3 && args[1] == "server") {
		return run_server(args[2]);
	}

	var sock = "/tmp/gsr-request-buffer-gate-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(sock);

	GLib.Subprocess? server = null;
	try {
		server = new GLib.Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			GLib.SubprocessFlags.NONE
		);
	} catch (GLib.Error e) {
		stderr.printf("FAIL request-buffer-gate: spawn server %s\n", e.message);
		return 2;
	}

	var wait_deadline = GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < wait_deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)) {
		stderr.printf("FAIL request-buffer-gate: server socket never appeared\n");
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 3,
	};

	var loop = new GLib.MainLoop();
	var connected = false;
	var connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "request-buffer-gate"),
	}, null, (obj, res) => {
		try {
			connected = client.connect.end(res);
			if (!connected) {
				connect_err = client.connect_error;
			}
		} catch (GLib.Error e) {
			connect_err = e.message;
		}
		loop.quit();
	});
	loop.run();
	if (!connected) {
		stderr.printf("FAIL request-buffer-gate: connect %s\n", connect_err);
		server.force_exit();
		return 2;
	}

	/*
	 * Prove the gap: call_poll has no buffer parameter; Request has no
	 * buffer property. Client cannot attach a memfd to the call.
	 */
	if (client.buffer_stream == null) {
		stderr.printf(
			"FAIL request-buffer-gate: no buffer_stream (live_handles)\n"
		);
		server.force_exit();
		return 1;
	}

	OLLMrpc.Response response;
	try {
		response = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.eat_fd",
			args = OLLMrpc.args("x", (int64) 5),
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL request-buffer-gate: call %s\n", e.message);
		server.force_exit();
		return 2;
	}

	var ok = false;
	if (response.args.size >= 1) {
		ok = response.args.get(0).get_boolean();
	}
	stderr.printf("request-buffer-gate eat_fd ok=%s\n", ok.to_string());
	server.force_exit();

	if (ok) {
		stderr.printf("PASS request-buffer-gate\n");
		return 0;
	}
	stderr.printf(
		"FAIL request-buffer-gate: call_poll cannot send Live.Buffer with "
		+ "Request (ImageContent.set_data). OPC: outbound Request buffer + "
		+ "server attach before dispatch.\n"
	);
	return 1;
}
