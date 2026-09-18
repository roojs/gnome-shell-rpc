/**
 * Gate: sustained live-shaped relay traffic must not wedge either end.
 *
 * The five single-shape reductions of the "hang after settle" freeze all PASS
 * (`reentrant-emit-call-gate`, `poll-coalesced-reply-gate`,
 * `poll-burst-strand-gate`, `buffer-invoke-gate`, `after-reply-gate`), so if
 * the transport is what wedges, it needs the live *combination*: deep invoke
 * nesting, re-entrant emits on the same hook, sync calls issued from inside
 * invoke handlers, and Notification traffic written mid-dispatch — repeated
 * thousands of times rather than once.
 *
 * This gate runs that combination against the product's own server pieces
 * (`src/rpc/{Listen,Connection,LiveCallback}.vala`) with no Clutter, stubs or
 * generator:
 *
 *   client call_poll(Gate.work depth=1)
 *     server emit on hook H            → client INVOKE
 *       handler: sync call_poll(Gate.ping) × PINGS   (server writes a
 *                Notification before each reply — the subscription storm)
 *       handler: if depth < MAX_DEPTH → call_poll(Gate.work depth+1), which
 *                emits H again re-entrantly (live logs show 86 of these in one
 *                session, nesting to depth 4)
 *       handler: RPC-Live-Callback.reply
 *   × ROUNDS
 *
 * A wedge on either side shows up as the client's `call_timeout_seconds`
 * firing (the server has no timeout — if it never returns from `hook.emit`
 * nothing else is served), so FAIL prints the round and depth it died at.
 *
 *   meson compile -C build nested-relay-storm-gate
 *   timeout 120 ./build/tests/call-sync-repro/nested-relay-storm-gate
 *
 * PASS → the transport survives the live shape at volume; the freeze needs
 *        something only the real session has (GJS handlers, Clutter recursion,
 *        real relayout) → keep chasing the consumer with a fresh capture.
 * FAIL → a reproducible wedge outside the product. Read which end stopped from
 *        the trace before blaming either side.
 */

/**
 * Read filter that never hands the parser more than {@link cap} bytes at once.
 *
 * `Bin.Stream.parse` starts every message with `DataInputStream.read_byte`,
 * which fills the whole 4096-byte buffer — that is the over-read that strands a
 * complete reply where `call_poll`'s `poll()` cannot see it. Capping each
 * underlying read below the **smallest message on the wire** (25 bytes here)
 * means a strand can only ever be a *partial* message, whose remainder is still
 * in the kernel, so the socket stays readable and poll always wakes.
 *
 * Consumer-side only: `Bin.Stream.in_stream` is a public settable property.
 */
class CappedInput : GLib.FilterInputStream
{
	public int cap = 8;

	public CappedInput(GLib.InputStream base_stream)
	{
		GLib.Object(base_stream: base_stream, close_base_stream: false);
	}

	public override ssize_t read(uint8[] buffer, GLib.Cancellable? cancellable = null)
		throws GLib.IOError
	{
		var n = buffer.length;
		if (n > this.cap) {
			n = this.cap;
		}
		return this.base_stream.read(buffer[0:n], cancellable);
	}

	public override bool close(GLib.Cancellable? cancellable = null) throws GLib.IOError
	{
		return true;
	}
}

/** Server exits after this long no matter what, so a client abort cannot orphan it. */
const int SERVER_LIFETIME_SECONDS = 120;

class Gate : GLib.Object
{
	public const int ROUNDS = 400;
	public const int MAX_DEPTH = 4;
	public const int PINGS = 3;

	/** Emits currently in flight on the server, for the trace. */
	public static int emit_depth = 0;
	public static int emits = 0;
	public static int pings = 0;
	public static int notifications = 0;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"work", "tu",
			"ping", "",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	/**
	 * Emit on the caller's hook, blocking until the client replies.
	 *
	 * The client's handler re-enters this method (same hook) until
	 * {@link MAX_DEPTH}, so emits nest exactly like the vfunc relays.
	 */
	public void work(OLLMrpc.Request request, uint64 callback_id, uint depth)
	{
		var conn = request.connection;
		var id = (int) callback_id;
		if (conn == null || !conn.callbacks.has_key(id)) {
			conn.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var hook = conn.callbacks.get(id);

		Gate.emit_depth++;
		Gate.emits++;
		hook.emit(OLLMrpc.args("u", depth));
		Gate.emit_depth--;

		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("u", depth),
		});
	}

	/**
	 * Plain call the client makes from inside its invoke handlers, with a
	 * Notification written first — the server-side signal subscriptions
	 * firing while a request is being served.
	 */
	public void ping(OLLMrpc.Request request)
	{
		Gate.pings++;
		var conn = request.connection;
		if (conn != null && conn.bin != null) {
			try {
				conn.bin.write(new OLLMrpc.Notification() {
					method = "gate::noise",
					object_type = "Gate",
					id = 0,
					message = "emit_depth=%d".printf(Gate.emit_depth),
				});
				Gate.notifications++;
			} catch (Error e) {
				stderr.printf("server: notification write ERR %s\n", e.message);
				stderr.flush();
			}
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("i", Gate.emit_depth),
		});
	}
}

static void boot_rpc()
{
	OLLMrpc.rpc_register(true);
	GnomeShellRpc.Rpc.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new GnomeShellRpc.Rpc.Daemon());
	/* The product server replaces the stock live singleton (Server.vala). */
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
		stderr.printf("FAIL nested-relay-storm-gate server: listen %s\n", sock);
		stderr.flush();
		return 2;
	}
	stderr.printf("server: listening %s\n", sock);
	stderr.flush();

	/*
	 * Self-destruct. The client aborts hard when a stranded reply lands after
	 * its timeout (Client.vala:1170 calls GLib.error), which skips the normal
	 * force_exit and leaves this process running forever, holding the socket
	 * and the inherited stderr pipe.
	 */
	var loop = new MainLoop();
	GLib.Timeout.add_seconds(SERVER_LIFETIME_SECONDS, () => {
		stderr.printf("server: lifetime reached, exiting\n");
		stderr.flush();
		loop.quit();
		return GLib.Source.REMOVE;
	});
	loop.run();

	listen.stop();
	FileUtils.unlink(sock);
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

	var sock = "/tmp/gsr-nested-relay-storm-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL nested-relay-storm-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL nested-relay-storm-gate: socket never appeared\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	/* GSR_STORM_HOLD=1 keeps a wedge open long enough to attach gdb. */
	var hold = GLib.Environment.get_variable("GSR_STORM_HOLD") != null;
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = hold ? 600 : 5,
	};

	uint64 cb_id = 0;
	var round = 0;
	var invokes = 0;
	var client_depth = 0;
	var max_client_depth = 0;
	var notifications = 0;
	var reply_rejected = 0;
	string stall_where = "";
	var stall_buffered = (size_t) 0;

	/*
	 * Bytes already pulled into the client's bin DataInputStream but not yet
	 * parsed. call_poll waits with poll() on the socket fd, which cannot see
	 * these — so a non-zero reading at the stall is a stranded message, not a
	 * missing write.
	 */
	size_t buffered_bytes() {
		if (client.bin == null || client.bin.in_stream == null) {
			return 0;
		}
		return client.bin.in_stream.get_available();
	}

	/*
	 * Report and exit at the stall. Unwinding is not an option: once a call
	 * has timed out, the stranded reply surfaces on the next wake and
	 * Client.vala:1170 turns it into GLib.error (abort), which would kill the
	 * summary — and leave the server subprocess orphaned.
	 */
	void fail_at_stall(string where) {
		if (stall_where != "") {
			return;
		}
		stall_where = where;
		stall_buffered = buffered_bytes();
		if (server != null) {
			server.force_exit();
		}
		FileUtils.unlink(sock);
		stderr.printf(
			"FAIL nested-relay-storm-gate: stalled — %s\n"
			+ "  client bin buffer at the stall: %" + size_t.FORMAT + " bytes unparsed\n"
			+ "  rounds=%d invokes=%d max invoke depth=%d notifications=%d"
			+ " rejected replies=%d\n"
			+ "  Non-zero buffer = the awaited reply was already read into this\n"
			+ "  process. call_poll waits with GLib.poll on the socket fd (now\n"
			+ "  empty) and on read_channel.get_buffer_condition(), which is\n"
			+ "  set_buffered(false) and so always 0 — neither can see it. The\n"
			+ "  server is parked in Live.Hook.emit and writes nothing more.\n"
			+ "  OPC: docs/bugs/2026-09-18-buffered-reply-strand-and-reentrant-emit.md\n",
			where, stall_buffered, round, invokes, max_client_depth,
			notifications, reply_rejected);
		stderr.flush();
		Process.exit(1);
	}

	client.notification.connect((notif) => {
		notifications++;
	});

	client.invoke.connect((call) => {
		invokes++;
		client_depth++;
		if (client_depth > max_client_depth) {
			max_client_depth = client_depth;
		}
		var depth = call.args.size > 0 ? call.args.get(0).get_uint() : 0;

		/* Sync calls from inside the handler, while the server is in emit. */
		for (var i = 0; i < Gate.PINGS && stall_where == ""; i++) {
			try {
				client.call_poll(new OLLMrpc.Request() {
					method = "Gate.ping",
				});
			} catch (Error e) {
				fail_at_stall("ping at depth %u: %s".printf(depth, e.message));
			}
		}

		/* Re-enter the SAME hook, like Clutter's measure recursion. */
		if (depth < Gate.MAX_DEPTH && stall_where == "") {
			try {
				client.call_poll(new OLLMrpc.Request() {
					method = "Gate.work",
					args = OLLMrpc.args("tu", cb_id, depth + 1),
				});
			} catch (Error e) {
				fail_at_stall("nested work at depth %u: %s".printf(depth, e.message));
			}
		}

		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "RPC-Live-Callback.reply",
				args = OLLMrpc.args("t", (uint64) call.reply_id),
			});
		} catch (Error e) {
			/* Expected for outer emits while same-hook-reentrant-emit-gate
			 * FAILs: the inner reply already consumed the row's reply_id. */
			reply_rejected++;
		}
		client_depth--;
	});

	var loop = new MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "nested-relay-storm-gate"),
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
		stderr.printf("FAIL nested-relay-storm-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	/*
	 * GSR_STORM_FILL=N — candidate consumer-side mitigation, no OPC change.
	 *
	 * The strand exists because one DataInputStream fill can pull the next
	 * whole message in behind the one being parsed. A fill is capped by the
	 * buffer size, so N=1 can never read past a message boundary: nothing
	 * complete is left where poll() cannot see it. Any N>1 only narrows the
	 * window — a fill straddling the boundary still strands whatever fits.
	 * bin.in_stream is a public settable property, so a consumer can do this
	 * after connect. Costs one read() syscall per byte; measure before
	 * believing in it.
	 */
	var cap = GLib.Environment.get_variable("GSR_STORM_CAP");
	if (cap != null && client.bin != null && client.bin.in_stream != null) {
		if (client.bin.in_stream.get_available() > 0) {
			stderr.printf("client: cannot swap in_stream, %" + size_t.FORMAT
				+ " bytes buffered\n", client.bin.in_stream.get_available());
			stderr.flush();
		} else {
			var capped = new CappedInput(client.bin.in_stream.base_stream) {
				cap = int.parse(cap),
			};
			var swapped = new GLib.DataInputStream(capped);
			swapped.set_byte_order(GLib.DataStreamByteOrder.BIG_ENDIAN);
			client.bin.in_stream = swapped;
			stderr.printf("client: capped reads at %s bytes\n", cap);
			stderr.flush();
		}
	}

	try {
		var reg = client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Callback.register",
		});
		cb_id = reg.args.get(0).get_uint64();
	} catch (Error e) {
		stderr.printf("FAIL nested-relay-storm-gate: register %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	var started = get_monotonic_time();
	for (round = 1; round <= Gate.ROUNDS && stall_where == ""; round++) {
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "Gate.work",
				args = OLLMrpc.args("tu", cb_id, (uint) 1),
			});
		} catch (Error e) {
			fail_at_stall("outer work round %d: %s".printf(round, e.message));
		}
		if (round % 100 == 0) {
			stderr.printf("client: round %d invokes=%d notifications=%d\n",
				round, invokes, notifications);
			stderr.flush();
		}
	}
	var elapsed_ms = (get_monotonic_time() - started) / 1000;

	server.force_exit();
	FileUtils.unlink(sock);

	stderr.printf(
		"PASS nested-relay-storm-gate: %d rounds, %d invokes, depth %d, "
		+ "%d notifications, %d rejected replies, %lld ms\n",
		Gate.ROUNDS, invokes, max_client_depth, notifications,
		reply_rejected, elapsed_ms);
	stderr.flush();
	return 0;
}
