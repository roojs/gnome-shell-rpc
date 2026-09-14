/**
 * Gate: {@code call_poll} + {@link OLLMrpc.Live.Buffer} fd on reply.
 *
 * Nest: Helper-WaylandClient.spawnv dups stdout (fd=77) and
 * {@code request.reply(…, new Live.Buffer(fd))}; client
 * {@code response.buffer == null} → DING {@code base_stream may not be null}.
 *
 * {@code call_poll} only polls the main bin socket; the **.fd** channel is
 * not drained, so {@code take_pending()} is empty when the Response is
 * demuxed.
 *
 *   meson compile -C build call-poll-buffer-fd-gate
 *   timeout 5 ./build/tests/call-sync-repro/call-poll-buffer-fd-gate
 *
 * FAIL → OPC: call_poll must poll/drain buffer_stream before take_pending.
 * No OPC code edits from this tree. Bug in OLLMchat docs/bugs/.
 */

class Gate : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"echo_fd", "",
			null
		);
		OLLMrpc.Request.register("Gate", new Gate());
	}

	/**
	 * Reply with a Live.Buffer holding a pipe read fd (content "ding\n").
	 */
	public void echo_fd(OLLMrpc.Request request)
	{
		int fds[2] = { -1, -1 };
		if (Posix.pipe(fds) < 0) {
			request.connection.reply_error(
				request,
				(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR,
				new GLib.IOError.FAILED("pipe failed")
			);
			return;
		}
		unowned uint8[] payload = (uint8[]) "ding\n".data;
		Posix.write(fds[1], payload, payload.length);
		Posix.close(fds[1]);
		stderr.printf("server echo_fd send_fd=%d\n", fds[0]);
		stderr.flush();
		request.reply(
			new OLLMrpc.Response() { id = request.id },
			new OLLMrpc.Live.Buffer(fds[0])
		);
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
		stderr.printf("FAIL call-poll-buffer-fd-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-call-poll-buffer-fd-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL call-poll-buffer-fd-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL call-poll-buffer-fd-gate: server socket never appeared\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 3,
	};

	var loop = new MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "call-poll-buffer-fd-gate"),
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
		stderr.printf("FAIL call-poll-buffer-fd-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		return 2;
	}

	int got_fd = -1;
	try {
		var response = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.echo_fd",
		});
		if (response.buffer != null) {
			got_fd = response.buffer.fd;
			response.buffer.fd = -1;
		}
	} catch (Error e) {
		stderr.printf("FAIL call-poll-buffer-fd-gate: call %s\n", e.message);
		stderr.flush();
		server.force_exit();
		return 2;
	}

	server.force_exit();
	FileUtils.unlink(sock);

	stderr.printf("call_poll echo_fd got_fd=%d\n", got_fd);
	stderr.flush();
	if (got_fd < 0) {
		stderr.printf(
			"FAIL call-poll-buffer-fd-gate: call_poll lost Live.Buffer "
			+ "(got_fd=%d). Nest: Helper spawnv stdout_fd>=0, client "
			+ "buffer=null. OPC call_poll must poll/drain .fd channel "
			+ "before take_pending.\n",
			got_fd
		);
		stderr.flush();
		return 1;
	}
	Posix.close(got_fd);
	stderr.printf("PASS call-poll-buffer-fd-gate\n");
	stderr.flush();
	return 0;
}
