/**
 * Gate: Ffi add_class ''o'' must resolve wire lease ids (uint64).
 *
 * Client {@code call_value} / live packing turns GObject args into lease
 * {@code t} on the wire. {@link OLLMrpc.Gi} resolves those back to
 * {@code connection.leases}. Ffi {@code pack("o")} only
 * {@code get_object()} — so Helper methods typed {@code GObject} get
 * null / GLib-CRITICAL when the client did the right thing.
 *
 * Shape: export Peer → call {@code Gate.echo} with args = [uint64 lid]
 * and signature {@code "o"}. Expect non-null Peer + ok reply.
 *
 * No OPC edits from this tree.
 *
 *   meson compile -C build ffi-o-lease-gate
 *   timeout 5 ./build/tests/call-sync-repro/ffi-o-lease-gate
 *
 * FAIL → OPC Ffi.pack("o") must resolve UINT64 → leases (like Gi).
 * PASS → consumer Helpers can take GObject args with signature "o".
 */

class Peer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }
}

class Gate : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Bin.register("Gate-Peer", typeof(Peer));
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"make", "",
			"echo", "o",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	public void make(OLLMrpc.Request request)
	{
		var peer = new Peer();
		request.connection.export(peer);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("o", peer),
		});
	}

	/**
	 * Expect a live Peer. Wire sends lease id (uint64) — Ffi must resolve.
	 */
	public void echo(OLLMrpc.Request request, Peer peer)
	{
		if (peer == null) {
			request.connection.reply_error(
				request,
				(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
				new GLib.IOError.FAILED(
					"Gate.echo: peer is null (Ffi o did not resolve lease)"
				)
			);
			return;
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("o", peer),
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
		stderr.printf("FAIL ffi-o-lease-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-ffi-o-lease-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL ffi-o-lease-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL ffi-o-lease-gate: server socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "ffi-o-lease-gate"),
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
		stderr.printf("FAIL ffi-o-lease-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	try {
		var made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
		var peer = made.retval.get_object() as Peer;
		if (peer == null || peer.rpc_lid == 0) {
			stderr.printf("FAIL ffi-o-lease-gate: make returned no peer lease\n");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 2;
		}

		/* Same shape as GnomeShellRpc.call_value object→lease rewrite. */
		var lease_arg = GLib.Value(typeof(uint64));
		lease_arg.set_uint64(peer.rpc_lid);
		var echo_req = new OLLMrpc.Request() {
			method = "Gate.echo",
		};
		echo_req.args.add(lease_arg);

		var echoed = client.call_poll(echo_req);
		var back = echoed.retval.get_object() as Peer;
		if (back == null) {
			stderr.printf(
				"FAIL ffi-o-lease-gate: echo retval null "
				+ "(Ffi o did not resolve lease id %llu)\n",
				peer.rpc_lid
			);
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 1;
		}
		stderr.printf(
			"PASS ffi-o-lease-gate: echo resolved lease %llu → Peer\n",
			peer.rpc_lid
		);
		stderr.flush();
	} catch (Error e) {
		stderr.printf(
			"FAIL ffi-o-lease-gate: %s "
			+ "(Ffi o must resolve UINT64 lease like Gi)\n",
			e.message
		);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 1;
	}

	server.force_exit();
	FileUtils.unlink(sock);
	return 0;
}
