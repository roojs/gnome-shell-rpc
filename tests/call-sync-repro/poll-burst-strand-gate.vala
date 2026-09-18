/**
 * Gate: a **burst** of server messages ahead of a {@code Live.Invoke} —
 * {@code call_poll} must drain its bin buffer, not one message per wake.
 *
 * This is the "hang after settle" freeze (2026-09-18 P2) reduced to two
 * real-libocrpc processes. At the live freeze both ends sit in {@code poll}:
 *
 *   client (gnome-shell-rpc): nested SYNC call_poll(Clutter-Actor.get_name)
 *       → Client.vala __poll  (reply never delivered)
 *   server (mutter-rpc): Live.Hook.emit → Connection.vala:48 emit_wait_poll
 *       → __poll  (waiting the client's reply to that emit)
 *
 * Why the client never wakes: {@link OLLMrpc.Client} reads through a
 * {@link GLib.DataInputStream} (buffered) but *waits* on a bare
 * {@link GLib.poll} of the socket fd plus {@code read_channel
 * .get_buffer_condition()} — and that IOChannel is {@code set_buffered(false)},
 * so its buffer condition is always empty. {@code poll_drain_readable} parses
 * **one** message and recurses only on that same always-false condition. So one
 * readable event drains exactly one message, however many were coalesced into
 * the read. Once the server stops writing (because it is blocked in
 * {@code hook.emit}), every remaining message — including the Invoke that would
 * release the emit, and any Response behind it — is stranded in the client's
 * bin buffer with nothing left to wake the poll.
 *
 * Our OWN server {@link GnomeShellRpc.Rpc.Connection.emit_wait_poll} already
 * fixes this class for the SERVER: {@code input_pending()} consults
 * {@code bin.in_stream.get_available()} and {@code drain_readable()} loops on
 * it. The libocrpc CLIENT has no equivalent.
 *
 * {@code poll-coalesced-reply-gate} only strands **one** message ([Notification]
 * [Response]) — a single extra wake still clears it. This gate strands a burst,
 * which is what the live emit storm produces.
 *
 * Shape:
 *   client call_poll(Gate.storm)
 *   server storm → write N Notifications in ONE flush → hook.emit(Invoke)
 *                → block in emit_wait_poll (writes nothing more)
 *   client must drain past the Notifications, dispatch the Invoke, reply
 *
 *   meson compile -C build poll-burst-strand-gate
 *   timeout 20 ./build/tests/call-sync-repro/poll-burst-strand-gate
 *
 * PASS → call_poll drains its buffer; burst stranding is safe at the transport
 *        → the live hang stays a consumer chase.
 * FAIL (timeout) → OPC: {@code Client.poll_drain_readable} / {@code call_poll}
 *        must loop while {@code bin.in_stream.get_available() > 0} before
 *        {@link GLib.poll}. File in OLLMchat docs/bugs/; do not edit OLLMchat
 *        from this tree; keep this FAIL gate.
 */

class Gate : GLib.Object
{
	/** Notifications written ahead of the Invoke, in one flush. */
	public const int BURST = 8;

	public static bool invoke_released = false;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"storm", "t",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	/**
	 * Write a burst of Notifications, then emit and block.
	 *
	 * The burst shares one socket write with nothing after it but the
	 * Invoke, so a client that drains one message per readable event ends
	 * up behind — and the server, blocked in emit, never writes again.
	 */
	public void storm(OLLMrpc.Request request, uint64 callback_id)
	{
		var conn = request.connection;
		var id = (int) callback_id;
		if (conn == null || conn.bin == null || !conn.callbacks.has_key(id)) {
			stderr.printf("server: storm no connection/bin/callback\n");
			stderr.flush();
			conn.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}

		try {
			for (var i = 0; i < Gate.BURST; i++) {
				conn.bin.write(new OLLMrpc.Notification() {
					method = "gate::noise",
					object_type = "Gate",
					id = 0,
					message = "burst-%d".printf(i),
				});
			}
			conn.bin.out_stream.flush();
		} catch (Error e) {
			stderr.printf("server: storm write ERR %s\n", e.message);
			stderr.flush();
			conn.reply_error(request, (int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
			return;
		}
		stderr.printf("server: wrote %d notifications in one flush\n", Gate.BURST);
		stderr.flush();

		var hook = conn.callbacks.get(id);
		stderr.printf("server: hook.emit BEGIN (nothing more written until reply)\n");
		stderr.flush();
		hook.emit(new Gee.ArrayList<GLib.Value?>());
		stderr.printf("server: hook.emit END replied=%s\n", hook.replied.to_string());
		stderr.flush();

		request.reply(new OLLMrpc.Response() {
			id = request.id,
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
		stderr.printf("FAIL poll-burst-strand-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-poll-burst-strand-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL poll-burst-strand-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL poll-burst-strand-gate: server socket never appeared\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 5,
	};

	int notif_n = 0;
	client.notification.connect((notif) => {
		notif_n++;
		stderr.printf("client: NOTIFICATION #%d %s\n", notif_n, notif.message);
		stderr.flush();
	});

	var invoke_n = 0;
	string reply_err = "";
	client.invoke.connect((call) => {
		invoke_n++;
		stderr.printf("client: INVOKE id=%d reply_id=%d after %d notifications\n",
			call.id, call.reply_id, notif_n);
		stderr.flush();
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "RPC-Live-Callback.reply",
				args = OLLMrpc.args("t", (uint64) call.reply_id),
			});
		} catch (Error e) {
			reply_err = e.message;
			stderr.printf("client: reply ERR %s\n", e.message);
			stderr.flush();
		}
	});

	var loop = new MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "poll-burst-strand-gate"),
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
		stderr.printf("FAIL poll-burst-strand-gate: connect %s\n", connect_err);
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
		stderr.printf("FAIL poll-burst-strand-gate: register %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}
	stderr.printf("client: callback id=%llu\n", cb_id);
	stderr.flush();

	string storm_err = "";
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.storm",
			args = OLLMrpc.args("t", cb_id),
		});
	} catch (Error e) {
		storm_err = e.message;
		stderr.printf("client: storm ERR %s\n", e.message);
		stderr.flush();
	}

	server.force_exit();
	FileUtils.unlink(sock);

	if (storm_err != "" || invoke_n == 0) {
		stderr.printf(
			"FAIL poll-burst-strand-gate: storm=%s invoke_n=%d notif_n=%d/%d\n"
			+ "  shape: %d Notifications coalesced ahead of the Invoke; the client\n"
			+ "  drains one message per readable event, the server is blocked in\n"
			+ "  hook.emit and writes nothing more → the Invoke is stranded in the\n"
			+ "  bin DataInputStream and poll(socket) never wakes.\n"
			+ "  fix (OLLMchat): drain while bin.in_stream.get_available() > 0 in\n"
			+ "  Client.poll_drain_readable / before poll() in call_poll.\n",
			storm_err == "" ? "ok" : storm_err,
			invoke_n, notif_n, Gate.BURST, Gate.BURST);
		stderr.flush();
		return 1;
	}
	if (reply_err != "") {
		stderr.printf("FAIL poll-burst-strand-gate: callback reply %s\n", reply_err);
		stderr.flush();
		return 1;
	}
	stderr.printf(
		"PASS poll-burst-strand-gate: invoke dispatched behind %d/%d notifications\n",
		notif_n, Gate.BURST);
	stderr.flush();
	return 0;
}
