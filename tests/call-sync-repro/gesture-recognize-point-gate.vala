/**
 * Shell 50 panel.js and searchController.js call
 * {@code ClickGesture.get_point_event(0)} from {@code recognize} /
 * {@code may-recognize}. Those names are not in the product
 * {@code Gsr-Clutter-Actor.add_signals} blocking switch, so the
 * compositor clears sequences ({@code COMPLETED} → {@code WAITING})
 * before the client handler runs. Guest mutter 18 then asserts
 * {@code point_index < sequences->len} and the client returns null.
 *
 *   meson compile -C build tests/call-sync-repro/gesture-recognize-point-gate
 *   timeout 5 ./build/tests/call-sync-repro/gesture-recognize-point-gate current
 *   timeout 5 ./build/tests/call-sync-repro/gesture-recognize-point-gate fixed
 *
 * {@code current} uses the product switch (recognize is one-way).
 * FAIL → get_point after emit sees 0 points. That is the live miss.
 * {@code fixed} marks recognize blocking. PASS → get_point during emit
 * still sees the press.
 */

private class Peer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }

	public signal void recognize();

	public int n_points = 1;
}

private static bool gate_blocking_recognize;

private class Gate : GLib.Object
{
	private static Peer? held_peer;

	public static void rpc_register()
	{
		OLLMrpc.Bin.register("Gate-Peer", typeof(Peer));
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"make", "",
			"fire", "",
			"get_point_event", "",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	/**
	 * Copy of {@code Gsr.Server.Clutter.Actor.add_signals} blocking
	 * names. {@code recognize} and {@code may-recognize} are not listed.
	 */
	private static bool product_blocking(string name)
	{
		switch (name) {
			case "before-update":
			case "button-press-event":
			case "button-release-event":
			case "captured-event":
			case "clicked":
			case "enter-event":
			case "event":
			case "key-press-event":
			case "key-release-event":
			case "leave-event":
			case "motion-event":
			case "scroll-event":
			case "touch-event":
			case "long-press":
				return true;
			default:
				return false;
		}
	}

	public void make(OLLMrpc.Request request)
	{
		var peer = new Peer();
		var lid = request.connection.export(peer);
		peer.rpc_lid = lid;
		Gate.held_peer = peer;
		var blocking = Gate.product_blocking("recognize");
		if (gate_blocking_recognize) {
			blocking = true;
		}
		var subscription = new OLLMrpc.Live.Subscription() {
			connection = request.connection,
			method = "recognize",
			id = (int) lid,
			blocking = blocking
		};
		if (!subscription.connect()) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("b", blocking),
		});
	}

	public void fire(OLLMrpc.Request request)
	{
		if (Gate.held_peer == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		Gate.held_peer.n_points = 1;
		Gate.held_peer.recognize();
		/* Stock clutter-gesture.c: COMPLETED with every sequence ended
		 * moves to WAITING and {@code g_array_set_size(sequences, 0)}. */
		Gate.held_peer.n_points = 0;
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}

	public void get_point_event(OLLMrpc.Request request)
	{
		if (Gate.held_peer == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var n = Gate.held_peer.n_points;
		if (n < 1) {
			stderr.printf(
				"server: clutter_gesture_get_point_event: "
				+ "assertion 'point_index < sequences->len' failed\n");
			stderr.flush();
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("i", n),
		});
	}
}

private static void boot_rpc()
{
	OLLMrpc.rpc_register(true);
	Gsr.Server.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new Gsr.Server.Daemon());
	Gsr.Server.LiveCallback.rpc_register();
	Gate.rpc_register();
}

private static int run_server(string socket_path, bool blocking_recognize)
{
	boot_rpc();
	gate_blocking_recognize = blocking_recognize;
	var listener = new Gsr.Server.Rpc.Listen(socket_path) {
		live_handles = true,
	};
	if (!listener.start()) {
		stderr.printf("FAIL gesture-recognize-point-gate server: listen\n");
		return 2;
	}
	new GLib.MainLoop().run();
	listener.stop();
	return 0;
}

private static string self_executable(string argv0)
{
	try {
		return GLib.FileUtils.read_link("/proc/self/exe");
	} catch (GLib.FileError e) {
		return argv0;
	}
}

int main(string[] args)
{
	var mode = "current";
	if (args.length >= 2 && args[1] != "server") {
		mode = args[1];
	}
	if (mode != "current" && mode != "fixed") {
		stderr.printf("FAIL gesture-recognize-point-gate: mode %s\n", mode);
		return 2;
	}
	if (args.length >= 3 && args[1] == "server") {
		return run_server(args[2], args.length >= 4 && args[3] == "fixed");
	}

	var socket_path = "/tmp/gsr-gesture-recognize-point-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(socket_path);

	GLib.Subprocess server;
	try {
		server = new GLib.Subprocess.newv(
			{
				self_executable(args[0]),
				"server",
				socket_path,
				mode
			},
			GLib.SubprocessFlags.NONE);
	} catch (GLib.Error e) {
		stderr.printf("FAIL gesture-recognize-point-gate: spawn %s\n",
			e.message);
		return 2;
	}

	var deadline = GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(socket_path, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(socket_path, GLib.FileTest.EXISTS)) {
		server.force_exit();
		stderr.printf("FAIL gesture-recognize-point-gate: socket never appeared\n");
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", socket_path) {
		live_handles = true,
		call_timeout_seconds = 3,
	};
	var loop = new GLib.MainLoop();
	var connected = false;
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "gesture-recognize-point-gate"),
	}, null, (obj, result) => {
		try {
			connected = client.connect.end(result);
		} catch (GLib.Error e) {
			connected = false;
		}
		loop.quit();
	});
	loop.run();
	if (!connected) {
		server.force_exit();
		stderr.printf("FAIL gesture-recognize-point-gate: connect\n");
		return 2;
	}

	var points_during_recognize = -1;
	var callback_error = "";
	client.notification.connect((notification) => {
		if (notification.method != "recognize") {
			return;
		}
		try {
			var response = client.call_poll(new OLLMrpc.Request() {
				method = "Gate.get_point_event",
			});
			if (response.args.size >= 1) {
				points_during_recognize = response.args.get(0).get_int();
			}
			if (notification.reply_id != 0) {
				client.call_poll(new OLLMrpc.Request() {
					method = "RPC-Live-Callback.reply",
					args = OLLMrpc.args(
						"t", (uint64) notification.reply_id),
				});
			}
		} catch (GLib.Error e) {
			callback_error = e.message;
		}
	});

	var subscribed_blocking = false;
	try {
		var made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
		subscribed_blocking = made.args.size == 1
			&& made.args.get(0).get_boolean();
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.fire",
		});
	} catch (GLib.Error e) {
		server.force_exit();
		GLib.FileUtils.unlink(socket_path);
		stderr.printf("FAIL gesture-recognize-point-gate: call %s\n",
			e.message);
		return 2;
	}

	server.force_exit();
	GLib.FileUtils.unlink(socket_path);

	if (callback_error != "") {
		stderr.printf("FAIL gesture-recognize-point-gate: %s error=%s\n",
			mode, callback_error);
		return 2;
	}
	if (points_during_recognize < 1) {
		stderr.printf(
			"FAIL gesture-recognize-point-gate %s: miss null "
			+ "blocking=%s points=%d\n",
			mode,
			subscribed_blocking.to_string(),
			points_during_recognize);
		return 1;
	}
	stderr.printf(
		"PASS gesture-recognize-point-gate %s: points=%d blocking=%s\n",
		mode,
		points_during_recognize,
		subscribed_blocking.to_string());
	return 0;
}
