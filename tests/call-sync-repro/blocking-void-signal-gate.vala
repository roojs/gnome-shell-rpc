/**
 * Gate: a blocking subscription to a void GObject signal must wait for the
 * client reply before the signal emission returns.
 *
 * ClutterStage::before-update is void. Marking its Subscription blocking is
 * ineffective when Subscription.emit treats a null return_value as one-way.
 *
 *   meson compile -C build tests/call-sync-repro/blocking-void-signal-gate
 *   timeout 5 ./build/tests/call-sync-repro/blocking-void-signal-gate
 *
 * PASS means the notification has a reply id and a nested observe call runs
 * while the server is still inside the void signal emission.
 * FAIL means libocrpc sent the nominally blocking void signal one-way.
 */

private class Peer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }

	public signal void tick();
}

private class Gate : GLib.Object
{
	private static Peer? held_peer;
	private static bool in_emit;
	private static bool observed_during_emit;

	public static void rpc_register()
	{
		OLLMrpc.Bin.register("Gate-Peer", typeof(Peer));
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"make", "",
			"fire", "",
			"observe", "",
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
		var subscription = new OLLMrpc.Live.Subscription() {
			connection = request.connection,
			method = "tick",
			id = (int) lid,
			blocking = true
		};
		if (!subscription.connect()) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}

	public void fire(OLLMrpc.Request request)
	{
		if (Gate.held_peer == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		Gate.observed_during_emit = false;
		Gate.in_emit = true;
		Gate.held_peer.tick();
		Gate.in_emit = false;
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("b", Gate.observed_during_emit),
		});
	}

	public void observe(OLLMrpc.Request request)
	{
		if (Gate.in_emit) {
			Gate.observed_during_emit = true;
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
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

private static int run_server(string socket_path)
{
	boot_rpc();
	var listener = new Gsr.Server.Rpc.Listen(socket_path) {
		live_handles = true,
	};
	if (!listener.start()) {
		stderr.printf("FAIL blocking-void-signal-gate server: listen\n");
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
	if (args.length >= 3 && args[1] == "server") {
		return run_server(args[2]);
	}

	var socket_path = "/tmp/gsr-blocking-void-signal-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(socket_path);

	GLib.Subprocess server;
	try {
		server = new GLib.Subprocess.newv(
			{self_executable(args[0]), "server", socket_path},
			GLib.SubprocessFlags.NONE);
	} catch (GLib.Error e) {
		stderr.printf("FAIL blocking-void-signal-gate: spawn %s\n", e.message);
		return 2;
	}

	var deadline = GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(socket_path, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(socket_path, GLib.FileTest.EXISTS)) {
		server.force_exit();
		stderr.printf("FAIL blocking-void-signal-gate: socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "blocking-void-signal-gate"),
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
		stderr.printf("FAIL blocking-void-signal-gate: connect\n");
		return 2;
	}

	var saw_tick = false;
	var saw_reply_id = false;
	var callback_error = "";
	client.notification.connect((notification) => {
		if (notification.method != "tick") {
			return;
		}
		saw_tick = true;
		saw_reply_id = notification.reply_id != 0;
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "Gate.observe",
			});
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

	var observed_during_emit = false;
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
		var response = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.fire",
		});
		observed_during_emit = response.args.size == 1
			&& response.args.get(0).get_boolean();
	} catch (GLib.Error e) {
		server.force_exit();
		GLib.FileUtils.unlink(socket_path);
		stderr.printf("FAIL blocking-void-signal-gate: call %s\n", e.message);
		return 2;
	}

	server.force_exit();
	GLib.FileUtils.unlink(socket_path);
	if (saw_tick && saw_reply_id && observed_during_emit
			&& callback_error == "") {
		stderr.printf(
			"PASS blocking-void-signal-gate: void signal waited for reply\n");
		return 0;
	}
	stderr.printf(
		"FAIL blocking-void-signal-gate: blocking void signal was one-way "
		+ "tick=%s reply-id=%s observed-during-emit=%s error=%s\n",
		saw_tick.to_string(),
		saw_reply_id.to_string(),
		observed_during_emit.to_string(),
		callback_error);
	return 1;
}
