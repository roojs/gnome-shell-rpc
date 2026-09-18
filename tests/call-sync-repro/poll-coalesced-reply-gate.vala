/**
 * Gate: a Response stranded behind an intervening message in the client's
 * bin DataInputStream buffer — {@code call_poll} blocks forever.
 *
 * This is the reduced two-process form of the live "hang after settle"
 * deadlock (2026-09-18). Paired backtraces at the freeze show:
 *
 *   client (gnome-shell-rpc): nested SYNC call_poll(Clutter-Actor.get_name)
 *       → Client.vala:1036 __poll  (blocked; reply never delivered)
 *   server (mutter-rpc): Live.Hook.emit → Connection.vala:48 emit_wait_poll
 *       → __poll  (blocked; waiting the client's reply to that emit)
 *
 * The server HAD already answered get_name (its log ends `recv … get_name`),
 * but an intervening server message (a Notification / Invoke from the emit
 * storm) coalesced ahead of the Response in a single client socket read. The
 * client's {@code bin.parse()} reads the intervening message and over-reads the
 * Response into the {@link GLib.DataInputStream} buffer. Both
 * {@code Client.poll_drain_readable} and {@code Client.call_poll} only consult
 * the IOChannel {@code get_buffer_condition()} + a bare {@link GLib.poll} on
 * the socket fd — never {@code bin.in_stream.get_available()}. So the Response
 * sits in the buffer, {@code poll(socket)} never wakes → deadlock.
 *
 * Our OWN server {@link GnomeShellRpc.Rpc.Connection.emit_wait_poll} already
 * fixes this exact class for the SERVER: {@code input_pending()} checks
 * {@code bin.in_stream.get_available()}. The libocrpc CLIENT {@code call_poll}
 * has the same latent bug, unfixed.
 *
 * Reduction: the server writes [Notification][Response] in ONE flush
 * (coalesced), so they share one client read. The client's plain
 * {@code call_poll(Gate.stall)} must still return the Response.
 *
 *   meson compile -C build poll-coalesced-reply-gate
 *   timeout 8 ./build/tests/call-sync-repro/poll-coalesced-reply-gate
 *
 * PASS → the client drains its bin buffer; the stranded-Response class is safe
 *        at the transport → the live hang is a consumer chase.
 * FAIL (timeout) → OPC: call_poll / poll_drain_readable must drain
 *        {@code bin.in_stream.get_available()} before poll(-1). File in
 *        OLLMchat docs/bugs/; do not edit OLLMchat from this tree; keep this
 *        FAIL gate.
 */

class Gate : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"stall", "",
			null
		);
		OLLMrpc.Request.register("Gate", new Gate());
	}

	/**
	 * Answer `stall`, but write a Notification immediately BEFORE the
	 * Response, both in a single flush so they share one client socket read.
	 * The awaited Response is then stranded in the client's bin buffer.
	 */
	public void stall(OLLMrpc.Request request)
	{
		var conn = request.connection;
		if (conn == null || conn.bin == null) {
			stderr.printf("server: stall no connection/bin\n");
			stderr.flush();
			return;
		}
		var noise = new OLLMrpc.Notification() {
			method = "gate::noise",
			object_type = "Gate",
			id = 0,
			message = "coalesce-before-reply",
		};
		var response = new OLLMrpc.Response() {
			id = request.id,
		};
		try {
			/* Intervening message the client parses FIRST. */
			conn.bin.write(noise);
			/* The awaited reply — over-read into the client bin buffer. */
			conn.bin.write(response);
			/* ONE flush → one coalesced socket write. */
			conn.bin.out_stream.flush();
		} catch (Error e) {
			stderr.printf("server: stall write ERR %s\n", e.message);
			stderr.flush();
			return;
		}
		stderr.printf("server: stall wrote [Notification][Response] coalesced\n");
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
		stderr.printf("FAIL poll-coalesced-reply-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-poll-coalesced-reply-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL poll-coalesced-reply-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL poll-coalesced-reply-gate: server socket never appeared\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 3,
	};

	int notif_n = 0;
	client.notification.connect((notif) => {
		notif_n++;
		stderr.printf("client: NOTIFICATION #%d method=%s\n", notif_n, notif.method);
		stderr.flush();
	});

	var loop = new MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "poll-coalesced-reply-gate"),
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
		stderr.printf("FAIL poll-coalesced-reply-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	string stall_err = "";
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.stall",
		});
	} catch (Error e) {
		stall_err = e.message;
		stderr.printf("client: stall ERR %s\n", e.message);
		stderr.flush();
	}

	server.force_exit();
	FileUtils.unlink(sock);

	if (stall_err != "") {
		stderr.printf(
			"FAIL poll-coalesced-reply-gate: stall %s\n"
			+ "  shape: [Notification][Response] coalesced in one client read;\n"
			+ "  Response stranded in bin DataInputStream, call_poll polls only\n"
			+ "  the socket fd + IOChannel IN → never bin.in_stream.get_available().\n"
			+ "  fix (OLLMchat): drain bin.in_stream.get_available() in\n"
			+ "  Client.poll_drain_readable / before poll(-1) in call_poll.\n",
			stall_err);
		stderr.flush();
		return 1;
	}
	stderr.printf(
		"PASS poll-coalesced-reply-gate: coalesced reply delivered (notif_n=%d)\n",
		notif_n);
	stderr.flush();
	return 0;
}
