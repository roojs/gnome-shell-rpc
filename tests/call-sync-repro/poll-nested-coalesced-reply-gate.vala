/**
 * Gate: a coalesced [Notification][Response] must reach a **nested**
 * {@code call_poll} — the one-deep case already passes.
 *
 * `poll-coalesced-reply-gate` proves the same pair is delivered when
 * {@code call_poll} runs at depth 1. This gate changes exactly one thing: the
 * awaited call is issued from **inside a Live.Invoke handler**, so
 * {@code poll_depth} is 2 and the server is blocked in {@code hook.emit} — it
 * will not write anything else until the client replies. That is the live
 * shape (docs/bugs/done/2026-09-18-hang-after-settle-race.md P2) and the shape
 * `nested-relay-storm-gate` wedges on:
 *
 *   server: recv Gate.ping (inside emit_wait_poll) → handler runs
 *   client: gets the handler's Notification … and never the Response
 *   client: call timed out Gate.ping after 5 s
 *
 * Mechanism: {@link OLLMrpc.Client} parses through a buffered
 * {@link GLib.DataInputStream} but waits with {@link GLib.poll} on the raw
 * socket fd, plus {@code read_channel.get_buffer_condition()} — and that
 * IOChannel is {@code set_buffered(false)}, so its buffer condition can never
 * report the bytes sitting in the stream buffer. When one read pulls both
 * messages in, the Notification is dispatched, the Response stays buffered,
 * and {@code poll()} has nothing left to wake it. With the server parked in
 * {@code hook.emit}, no further write ever arrives to nudge it.
 *
 * Our OWN server fixed this class on its side: {@link
 * GnomeShellRpc.Rpc.Connection.input_pending} consults
 * {@code bin.in_stream.get_available()} before polling. {@link
 * OLLMrpc.Client.call_poll} / {@code poll_drain_readable} have no equivalent.
 *
 *   meson compile -C build poll-nested-coalesced-reply-gate
 *   timeout 30 ./build/tests/call-sync-repro/poll-nested-coalesced-reply-gate
 *
 * PASS → nested call_poll drains its stream buffer; look elsewhere.
 * FAIL (timeout) → OPC: drain {@code bin.in_stream.get_available()} in
 *        {@code Client.poll_drain_readable} and before {@link GLib.poll} in
 *        {@code call_poll}. File in OLLMchat docs/bugs/; do not edit OLLMchat
 *        from this tree; keep this FAIL gate.
 */

class Gate : GLib.Object
{
	public static bool stall_ran = false;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"provoke", "t",
			"stall", "",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	/** Park the server inside hook.emit — it writes nothing more. */
	public void provoke(OLLMrpc.Request request, uint64 callback_id)
	{
		var conn = request.connection;
		var id = (int) callback_id;
		if (conn == null || !conn.callbacks.has_key(id)) {
			conn.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		stderr.printf("server: hook.emit BEGIN\n");
		stderr.flush();
		conn.callbacks.get(id).emit(new Gee.ArrayList<GLib.Value?>());
		stderr.printf("server: hook.emit END\n");
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}

	/**
	 * Answer with a Notification immediately ahead of the Response, both in
	 * one flush, so they share one client read. Dispatched from
	 * {@code drain_readable} inside {@code emit_wait_poll}.
	 */
	public void stall(OLLMrpc.Request request)
	{
		Gate.stall_ran = true;
		var conn = request.connection;
		if (conn == null || conn.bin == null) {
			stderr.printf("server: stall no connection/bin\n");
			stderr.flush();
			return;
		}
		try {
			conn.bin.write(new OLLMrpc.Notification() {
				method = "gate::noise",
				object_type = "Gate",
				id = 0,
				message = "coalesce-before-reply",
			});
			conn.bin.write(new OLLMrpc.Response() {
				id = request.id,
			});
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
	GnomeShellRpc.Rpc.LiveCallback.rpc_register();
	Gate.rpc_register();
}

static int run_server(string sock)
{
	boot_rpc();
	var listen = new GnomeShellRpc.Rpc.Listen(sock) {
		live_handles = true,
	};
	if (!listen.start()) {
		stderr.printf("FAIL poll-nested-coalesced-reply-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-poll-nested-coalesced-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL poll-nested-coalesced-reply-gate: spawn %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL poll-nested-coalesced-reply-gate: no socket\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 5,
	};

	var notif_n = 0;
	client.notification.connect((notif) => {
		notif_n++;
		stderr.printf("client: NOTIFICATION #%d %s\n", notif_n, notif.message);
		stderr.flush();
	});

	var invoke_n = 0;
	string stall_err = "";
	client.invoke.connect((call) => {
		invoke_n++;
		stderr.printf("client: INVOKE id=%d reply_id=%d (poll depth 2 from here)\n",
			call.id, call.reply_id);
		stderr.flush();
		/* Nested sync call — the server answers from inside emit_wait_poll. */
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "Gate.stall",
			});
			stderr.printf("client: nested Gate.stall returned\n");
			stderr.flush();
		} catch (Error e) {
			stall_err = e.message;
			stderr.printf("client: nested Gate.stall ERR %s\n", e.message);
			stderr.flush();
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
		args = OLLMrpc.args("is", 1, "poll-nested-coalesced-reply-gate"),
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
		stderr.printf("FAIL poll-nested-coalesced-reply-gate: connect %s\n", connect_err);
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
		stderr.printf("FAIL poll-nested-coalesced-reply-gate: register %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

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

	if (stall_err != "" || provoke_err != "") {
		stderr.printf(
			"FAIL poll-nested-coalesced-reply-gate: stall=%s provoke=%s\n"
			+ "  notifications=%d invokes=%d\n"
			+ "  shape: server answered from inside hook.emit with\n"
			+ "  [Notification][Response] in one flush; the client parsed the\n"
			+ "  Notification and left the Response in its bin DataInputStream.\n"
			+ "  call_poll then polls the socket fd — which is empty — while the\n"
			+ "  server waits in emit and writes nothing more. Deadlock.\n"
			+ "  fix (OLLMchat): drain bin.in_stream.get_available() in\n"
			+ "  Client.poll_drain_readable / before poll() in call_poll, the way\n"
			+ "  GnomeShellRpc.Rpc.Connection.input_pending already does server-side.\n",
			stall_err == "" ? "ok" : stall_err,
			provoke_err == "" ? "ok" : provoke_err,
			notif_n, invoke_n);
		stderr.flush();
		return 1;
	}
	stderr.printf(
		"PASS poll-nested-coalesced-reply-gate: nested coalesced reply delivered "
		+ "(notifications=%d invokes=%d)\n", notif_n, invoke_n);
	stderr.flush();
	return 0;
}
