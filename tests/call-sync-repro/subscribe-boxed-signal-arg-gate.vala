/**
 * Gate: named-signal {@link OLLMrpc.Notification.args} must pack a
 * GType boxed that is not {@link GLib.Bytes}.
 *
 * Registered boxed on {@link OLLMrpc.Notification.args} (not only
 * {@link GLib.Bytes}). Nested analog: {@code ClutterStage::before-update}
 * {@code ClutterFrame}. Both peers {@link OLLMrpc.Bin.register} the GType.
 *
 *   meson compile -C build subscribe-boxed-signal-arg-gate
 *   timeout 5 ./build/tests/call-sync-repro/subscribe-boxed-signal-arg-gate
 *
 * PASS → {@code framed} notification with a {@code GVariantType} arg.
 * FAIL → write error / connection reset. File in OLLMchat; do not Idle.
 */

class Peer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }

	public signal void framed(GLib.VariantType spec);

	public void fire()
	{
		this.framed(new GLib.VariantType("i"));
	}
}

class Gate : GLib.Object
{
	public static Peer? held_peer;

	public static void rpc_register()
	{
			OLLMrpc.Bin.register("Gate-Peer", typeof(Peer));
			OLLMrpc.Bin.register("GLib.VariantType", typeof(GLib.VariantType));
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"make", "",
			"fire", "",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	public void make(OLLMrpc.Request request)
	{
		var peer = new Peer();
		var lid = request.connection.export(peer);
		peer.rpc_lid = lid;
		Gate.held_peer = peer;
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("t", lid),
		});
	}

	public void fire(OLLMrpc.Request request)
	{
		if (Gate.held_peer == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		stderr.printf("server: fire framed(VariantType i)\n");
		stderr.flush();
		Gate.held_peer.fire();
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
		stderr.printf("FAIL subscribe-boxed-signal-arg-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-subscribe-boxed-signal-arg-gate-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(sock);

	GLib.Subprocess? server = null;
	try {
		server = new GLib.Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			GLib.SubprocessFlags.NONE
		);
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-boxed-signal-arg-gate: spawn server %s\n", e.message);
		return 2;
	}

	var wait_deadline = GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < wait_deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)) {
		stderr.printf("FAIL subscribe-boxed-signal-arg-gate: server socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "subscribe-boxed-signal-arg-gate"),
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
		stderr.printf("FAIL subscribe-boxed-signal-arg-gate: connect %s\n", connect_err);
		server.force_exit();
		return 2;
	}

	string? got_method = null;
	string? got_type = null;
	string? fire_err = null;
	client.notification.connect((notif) => {
		var tname = "";
		if (notif.args != null && notif.args.size > 0 && notif.args.get(0) != null) {
			tname = notif.args.get(0).type().name();
		}
		stderr.printf(
			"client: notification method=%s id=%d args=%d arg0type=%s\n",
			notif.method, notif.id,
			notif.args == null ? 0 : notif.args.size,
			tname
		);
		stderr.flush();
		if (notif.method == "framed") {
			got_method = notif.method;
			got_type = tname;
		}
	});

	OLLMrpc.Response made;
	try {
		made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-boxed-signal-arg-gate: make %s\n", e.message);
		server.force_exit();
		return 2;
	}
	if (made.args.size < 1) {
		stderr.printf("FAIL subscribe-boxed-signal-arg-gate: make no lease\n");
		server.force_exit();
		return 2;
	}
	var lid = made.args.get(0).get_uint64();
	stderr.printf("client: peer lid=%llu\n", lid);
	stderr.flush();

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Subscribe.rpc_signal",
			lease_id = lid,
			args = OLLMrpc.args("s", "framed"),
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-boxed-signal-arg-gate: subscribe %s\n", e.message);
		server.force_exit();
		return 2;
	}

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.fire",
		});
	} catch (GLib.Error e) {
		fire_err = e.message;
		stderr.printf("client: fire error %s\n", fire_err);
		stderr.flush();
	}

	if (got_method == null) {
		var wait = new GLib.MainLoop();
		GLib.Timeout.add(1000, () => {
			wait.quit();
			return GLib.Source.REMOVE;
		});
		wait.run();
	}

	server.force_exit();

	stderr.printf(
		"subscribe-boxed-signal-arg-gate method=%s arg0type=%s fire_err=%s\n",
		got_method ?? "(none)",
		got_type ?? "(none)",
		fire_err ?? "(none)"
	);

	if (got_method == "framed" && got_type != null && got_type.length > 0) {
		stderr.printf("PASS subscribe-boxed-signal-arg-gate\n");
		return 0;
	}
	stderr.printf(
		"FAIL subscribe-boxed-signal-arg-gate: named signal framed(VariantType) "
		+ "did not pack on Notification.args (StreamValue boxed besides Bytes).\n"
	);
	return 1;
}
