/**
 * Gate: {@code RPC-Live-Subscribe.rpc_signal} on a named GObject signal
 * with parameters must deliver those parameters on the client
 * {@link OLLMrpc.Notification}.
 *
 * Stock {@code ClutterStage::before-update} is {@code (StageView, Frame)}.
 * {@code Transition::stopped} is {@code (bool is_finished)}. Named-signal
 * parameters land on {@link OLLMrpc.Notification.args} (not
 * {@code message}; {@code notify::} still uses {@code message}).
 *
 *   meson compile -C build subscribe-signal-args-gate
 *   timeout 5 ./build/tests/call-sync-repro/subscribe-signal-args-gate
 *
 * PASS → {@code Notification.args[0]} is {@code "hello"}.
 * FAIL → OPC Subscription.emit drops GObject signal args. File in
 *        OLLMchat docs/bugs/; do not work around in Runtime/Laters.
 */

class Peer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }

	public signal void pinged(string payload);

	public void fire(string payload)
	{
		this.pinged(payload);
	}
}

class Gate : GLib.Object
{
	public static Peer? held_peer;

	public static void rpc_register()
	{
		OLLMrpc.Bin.register("Gate-Peer", typeof(Peer));
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"make", "",
			"fire", "s",
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

	public void fire(OLLMrpc.Request request, string payload)
	{
		if (Gate.held_peer == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		stderr.printf("server: fire payload=%s\n", payload);
		stderr.flush();
		Gate.held_peer.fire(payload);
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
		stderr.printf("FAIL subscribe-signal-args-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-subscribe-signal-args-gate-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(sock);

	GLib.Subprocess? server = null;
	try {
		server = new GLib.Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			GLib.SubprocessFlags.NONE
		);
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-signal-args-gate: spawn server %s\n", e.message);
		return 2;
	}

	var wait_deadline = GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < wait_deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)) {
		stderr.printf("FAIL subscribe-signal-args-gate: server socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "subscribe-signal-args-gate"),
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
		stderr.printf("FAIL subscribe-signal-args-gate: connect %s\n", connect_err);
		server.force_exit();
		return 2;
	}

	string? got_method = null;
	string? got_payload = null;
	client.notification.connect((notif) => {
		var arg0 = "";
		if (notif.args != null && notif.args.size > 0
				&& notif.args.get(0) != null
				&& notif.args.get(0).holds(GLib.Type.STRING)) {
			arg0 = notif.args.get(0).get_string();
		}
		stderr.printf(
			"client: notification method=%s id=%d args=%d arg0=%s message=%s\n",
			notif.method, notif.id,
			notif.args == null ? 0 : notif.args.size,
			arg0, notif.message
		);
		stderr.flush();
		if (notif.method == "pinged") {
			got_method = notif.method;
			got_payload = arg0;
		}
	});

	OLLMrpc.Response made;
	try {
		made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-signal-args-gate: make %s\n", e.message);
		server.force_exit();
		return 2;
	}
	if (made.args.size < 1) {
		stderr.printf("FAIL subscribe-signal-args-gate: make no lease\n");
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
			args = OLLMrpc.args("s", "pinged"),
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-signal-args-gate: subscribe %s\n", e.message);
		server.force_exit();
		return 2;
	}

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.fire",
			args = OLLMrpc.args("s", "hello"),
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-signal-args-gate: fire %s\n", e.message);
		server.force_exit();
		return 2;
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
		"subscribe-signal-args-gate method=%s args[0]=%s\n",
		got_method ?? "(none)",
		got_payload ?? "(none)"
	);

	if (got_method == "pinged" && got_payload == "hello") {
		stderr.printf("PASS subscribe-signal-args-gate\n");
		return 0;
	}
	stderr.printf(
		"FAIL subscribe-signal-args-gate: named signal pinged(\"hello\") "
		+ "did not arrive on Notification.args.\n"
	);
	return 1;
}
