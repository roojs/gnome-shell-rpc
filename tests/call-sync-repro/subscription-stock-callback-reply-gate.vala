/**
 * Gate: stock libocrpc Callback.reply must complete a blocking Subscription.
 *
 * The subscription waiter uses Hook.reply_id/reply_args, while stock
 * Callback.reply currently checks only Hook.complete().
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
			null);
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
		request.reply(new OLLMrpc.Response());
	}

	public void fire(OLLMrpc.Request request)
	{
		if (Gate.held_peer == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		request.reply(new OLLMrpc.Response() {
			args = OLLMrpc.args("u", Gate.held_peer.ask()),
		});
	}
}

private static void boot_rpc()
{
	OLLMrpc.rpc_register(true);
	Gsr.Server.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new Gsr.Server.Daemon());
	Gate.rpc_register();
}

private static int run_server(string socket_path)
{
	boot_rpc();
	var listener = new Gsr.Server.Rpc.Listen(socket_path) {
		live_handles = true,
	};
	if (!listener.start()) {
		return 2;
	}
	new GLib.MainLoop().run();
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
	var socket_path = "/tmp/gsr-subscription-stock-callback-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(socket_path);
	GLib.Subprocess server;
	try {
		server = new GLib.Subprocess.newv(
			{self_executable(args[0]), "server", socket_path},
			GLib.SubprocessFlags.NONE);
	} catch (GLib.Error e) {
		return 2;
	}
	var deadline = GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(socket_path, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(socket_path, GLib.FileTest.EXISTS)) {
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", socket_path) {
		live_handles = true,
		call_timeout_seconds = 2,
	};
	var loop = new GLib.MainLoop();
	var connected = false;
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "subscription-stock-callback-reply-gate"),
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
		return 2;
	}

	var callback_error = "";
	client.notification.connect((notification) => {
		if (notification.method != "ask") {
			return;
		}
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
	var outer_error = "";
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
		var response = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.fire",
		});
		if (response.args.size == 1) {
			returned = response.args.get(0).get_uint();
		}
	} catch (GLib.Error e) {
		outer_error = e.message;
	}
	server.force_exit();
	GLib.FileUtils.unlink(socket_path);
	if (returned == 7 && callback_error == "" && outer_error == "") {
		stderr.printf(
			"PASS subscription-stock-callback-reply-gate: returned 7\n");
		return 0;
	}
	stderr.printf(
		"FAIL subscription-stock-callback-reply-gate: "
		+ "returned=%u callback-error=%s outer-error=%s\n",
		returned, callback_error, outer_error);
	return 1;
}
