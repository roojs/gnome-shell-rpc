/**
 * Gate: a blocking subscription must copy a uint handler reply into the
 * GObject signal return value.
 *
 *   meson compile -C build tests/call-sync-repro/subscription-uint-return-gate
 *   timeout 5 ./build/tests/call-sync-repro/subscription-uint-return-gate
 *
 * PASS means the remote uint reply becomes the signal emission result.
 * FAIL means Live.Subscription.emit discards it or writes the wrong GValue type.
 */

private class Peer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }

	public signal uint ask();
}

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
			method = "ask",
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
		var returned = Gate.held_peer.ask();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("u", returned),
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
		stderr.printf("FAIL subscription-uint-return-gate server: listen\n");
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

	var socket_path = "/tmp/gsr-subscription-uint-return-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(socket_path);

	GLib.Subprocess server;
	try {
		server = new GLib.Subprocess.newv(
			{self_executable(args[0]), "server", socket_path},
			GLib.SubprocessFlags.NONE);
	} catch (GLib.Error e) {
		stderr.printf(
			"FAIL subscription-uint-return-gate: spawn %s\n", e.message);
		return 2;
	}

	var deadline = GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(socket_path, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(socket_path, GLib.FileTest.EXISTS)) {
		server.force_exit();
		stderr.printf(
			"FAIL subscription-uint-return-gate: socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "subscription-uint-return-gate"),
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
		stderr.printf("FAIL subscription-uint-return-gate: connect\n");
		return 2;
	}

	var saw_ask = false;
	var saw_reply_id = false;
	var callback_error = "";
	client.notification.connect((notification) => {
		if (notification.method != "ask") {
			return;
		}
		saw_ask = true;
		saw_reply_id = notification.reply_id != 0;
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "RPC-Live-Callback.reply",
				args = OLLMrpc.args(
					"tu", (uint64) notification.reply_id, (uint) 7),
			});
		} catch (GLib.Error e) {
			callback_error = e.message;
		}
	});

	var returned = (uint) 0;
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
		var response = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.fire",
		});
		if (response.args.size == 1
				&& response.args.get(0).type() == GLib.Type.UINT) {
			returned = response.args.get(0).get_uint();
		}
	} catch (GLib.Error e) {
		server.force_exit();
		GLib.FileUtils.unlink(socket_path);
		stderr.printf(
			"FAIL subscription-uint-return-gate: call %s\n", e.message);
		return 2;
	}

	server.force_exit();
	GLib.FileUtils.unlink(socket_path);
	if (saw_ask && saw_reply_id && returned == 7 && callback_error == "") {
		stderr.printf(
			"PASS subscription-uint-return-gate: uint reply returned 7\n");
		return 0;
	}
	stderr.printf(
		"FAIL subscription-uint-return-gate: uint reply lost "
		+ "ask=%s reply-id=%s returned=%u error=%s\n",
		saw_ask.to_string(),
		saw_reply_id.to_string(),
		returned,
		callback_error);
	return 1;
}
