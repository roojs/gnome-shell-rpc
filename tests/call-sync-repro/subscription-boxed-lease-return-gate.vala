/**
 * Gate: a client-side proxy lease can be resolved back to the server's boxed
 * value before a blocking subscription fills the GObject signal return.
 */

private class Peer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }

	public signal GLib.VariantType? ask();
}

private class BoxRow : GLib.Object
{
	public GLib.VariantType boxed = new GLib.VariantType("s");
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
			"reply_box", "tt",
			null);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	public void make(OLLMrpc.Request request)
	{
		var peer = new Peer();
		var peer_lid = request.connection.export(peer);
		peer.rpc_lid = peer_lid;
		Gate.held_peer = peer;
		var row_lid = request.connection.export(new BoxRow());
		var subscription = new OLLMrpc.Live.Subscription() {
			connection = request.connection,
			method = "ask",
			id = (int) peer_lid,
			blocking = true
		};
		if (!subscription.connect()) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("t", (uint64) row_lid),
		});
	}

	public void reply_box(
		OLLMrpc.Request request,
		uint64 reply_id,
		uint64 row_lid
	) {
		var row = request.connection.leases.get((int) row_lid) as BoxRow;
		if (row == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var boxed = GLib.Value(typeof(GLib.VariantType));
		boxed.set_boxed(row.boxed);
		var values = new Gee.ArrayList<GLib.Value?>();
		values.add(boxed);
		if (Gsr.Server.LiveCallback.complete(
				request.connection, (int) reply_id, values)) {
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
			return;
		}
		request.connection.reply_error(
			request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
	}

	public void fire(OLLMrpc.Request request)
	{
		if (Gate.held_peer == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var returned = Gate.held_peer.ask();
		var expected = new GLib.VariantType("s");
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args(
				"b", returned != null && returned.equal(expected)),
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
	var socket_path = "/tmp/gsr-subscription-boxed-return-%d.sock".printf(
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
		call_timeout_seconds = 3,
	};
	var loop = new GLib.MainLoop();
	var connected = false;
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "subscription-boxed-return-gate"),
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

	var saw_ask = false;
	var row_lid = (uint64) 0;
	client.notification.connect((notification) => {
		if (notification.method != "ask") {
			return;
		}
		saw_ask = true;
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "Gate.reply_box",
				args = OLLMrpc.args(
					"tt", (uint64) notification.reply_id, row_lid),
			});
		} catch (GLib.Error e) {
		}
	});

	var matched = false;
	try {
		var made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
		row_lid = made.args.get(0).get_uint64();
		var fired = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.fire",
		});
		matched = fired.args.get(0).get_boolean();
	} catch (GLib.Error e) {
	}
	server.force_exit();
	GLib.FileUtils.unlink(socket_path);
	if (saw_ask && matched) {
		stderr.printf(
			"PASS subscription-boxed-lease-return-gate: boxed reply restored\n");
		return 0;
	}
	stderr.printf(
		"FAIL subscription-boxed-lease-return-gate: ask=%s matched=%s\n",
		saw_ask.to_string(), matched.to_string());
	return 1;
}
