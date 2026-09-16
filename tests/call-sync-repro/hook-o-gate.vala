/**
 * Gate: Live.Hook.emit of a live GObject ({@code "o"}) must decode on
 * the client as {@code get_object()} — same remaining-C-arg shape as
 * Helper.LayoutManager ({@code "od"} / {@code "odddd"}).
 *
 * Helper.Actor / Constraint hooks send {@code export()} as {@code "t"}
 * because the callback is already bound on that actor. LayoutManager
 * {@code this} is the LM; the container is a different GObject and
 * must appear as {@code "o"} on the Invoke.
 *
 * Shape: {@code Gate.make} returns a lease {@code "t"} only (no
 * Response.retval object — Helper-Actor.create shape, so Gate-Peer is
 * not TOKEN_REG_TYPE'd on a property stream). {@code Gate.emit_od}
 * does {@code hook.emit(args("od", peer, 1.5))}. Client Invoke must
 * {@code get_object()} a non-null Peer.
 *
 * No OPC edits from this tree.
 *
 *   meson compile -C build hook-o-gate
 *   timeout 5 ./build/tests/call-sync-repro/hook-o-gate
 *
 * FAIL → OPC Invoke.args / StreamValue.read must skip TOKEN_REG_TYPE
 * (0xFF) the same way Serializable.bin_read and Stream.parse do.
 * PASS → consumer Helper LM {@code "od"} + {@code get_object()} is fine.
 */

class Peer : GLib.Object, OLLMrpc.Live.Handle
{
	public uint64 rpc_lid { get; set construct; default = 0; }
}

class Gate : GLib.Object
{
	public static Peer? held_peer;
	public static OLLMrpc.Live.Hook? held_hook;

	public static void rpc_register()
	{
		OLLMrpc.Bin.register("Gate-Peer", typeof(Peer));
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"make", "",
			"emit_od", "t",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	/**
	 * Mint + export. Reply lease id only — not retval {@code "o"} —
	 * so the first write_gtype of Gate-Peer is the Hook emit.
	 */
	public void make(OLLMrpc.Request request)
	{
		var peer = new Peer();
		var lid = request.connection.export(peer);
		Gate.held_peer = peer;
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("t", lid),
		});
	}

	public void emit_od(OLLMrpc.Request request, uint64 callback_id)
	{
		var id = (int) callback_id;
		if (Gate.held_peer == null
				|| !request.connection.callbacks.has_key(id)) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var hook = request.connection.callbacks.get(id);
		Gate.held_hook = hook;
		stderr.printf("server: emit od BEGIN\n");
		stderr.flush();
		hook.emit(OLLMrpc.args("od", Gate.held_peer, 1.5));
		stderr.printf("server: emit od END replied=%s\n",
			hook.replied.to_string());
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
		stderr.printf("FAIL hook-o-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-hook-o-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL hook-o-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL hook-o-gate: server socket never appeared\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 3,
	};

	Peer? got_peer = null;
	double got_d = 0;
	string invoke_err = "";
	client.invoke.connect((call) => {
		stderr.printf("client: INVOKE id=%d nargs=%d\n",
			call.id, call.args.size);
		stderr.flush();
		try {
			if (call.args.size < 2) {
				invoke_err = "Invoke args size %d want 2".printf(
					call.args.size);
			} else {
				got_peer = call.args.get(0).get_object() as Peer;
				got_d = call.args.get(1).get_double();
			}
			client.call_poll(new OLLMrpc.Request() {
				method = "RPC-Live-Callback.reply",
				args = OLLMrpc.args("t", (uint64) call.reply_id),
			});
		} catch (Error e) {
			invoke_err = e.message;
			stderr.printf("client: invoke ERR %s\n", e.message);
			stderr.flush();
		}
	});

	var loop = new MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "hook-o-gate"),
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
		stderr.printf("FAIL hook-o-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	uint64 lid = 0;
	try {
		var made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
		lid = made.args.get(0).get_uint64();
	} catch (Error e) {
		stderr.printf("FAIL hook-o-gate: make %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}
	if (lid == 0) {
		stderr.printf("FAIL hook-o-gate: make returned lid 0\n");
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}
	var minted = (Peer) GLib.Object.new(typeof(Peer), "rpc-lid", lid);
	client.proxies.set((int) lid, minted);

	uint64 cb_id = 0;
	try {
		var reg = client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Callback.register",
		});
		cb_id = reg.args.get(0).get_uint64();
	} catch (Error e) {
		stderr.printf("FAIL hook-o-gate: register %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.emit_od",
			args = OLLMrpc.args("t", cb_id),
		});
	} catch (Error e) {
		stderr.printf(
			"FAIL hook-o-gate: emit_od %s "
			+ "(Invoke.args StreamValue.read of live \"o\")\n",
			e.message
		);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 1;
	}

	server.force_exit();
	FileUtils.unlink(sock);

	if (invoke_err != "") {
		stderr.printf(
			"FAIL hook-o-gate: %s "
			+ "(Invoke.args StreamValue.read of live \"o\")\n",
			invoke_err
		);
		stderr.flush();
		return 1;
	}
	if (got_peer == null) {
		stderr.printf(
			"FAIL hook-o-gate: get_object() null "
			+ "(Live.Hook \"o\" did not decode Peer lid %llu)\n",
			lid
		);
		stderr.flush();
		return 1;
	}
	if (got_peer != minted) {
		stderr.printf(
			"FAIL hook-o-gate: get_object() reminted "
			+ "(want proxies identity lid %llu)\n",
			lid
		);
		stderr.flush();
		return 1;
	}
	if (got_d != 1.5) {
		stderr.printf("FAIL hook-o-gate: double %g want 1.5\n", got_d);
		stderr.flush();
		return 1;
	}
	stderr.printf(
		"PASS hook-o-gate: emit od → Peer lid %llu get_object identity\n",
		lid
	);
	stderr.flush();
	return 0;
}
