/**
 * Gate: a subscribed named signal whose GObject argument this connection
 * has never seen must still arrive, and the connection must stay up.
 *
 * Live shape: mutter emits workspace window-added (and friends) with a
 * new Meta.Window while the window is still being constructed, before
 * Meta.Display::window-created lets the server export it. OPC
 * Subscription.emit packs the arg as-is; StreamValue then throws
 * "live object MetaWindowWayland not in connection.lease_ids",
 * Connection.write calls stop(), and the shell client dies.
 *
 *   meson compile -C build subscribe-unexported-object-arg-gate
 *   timeout 5 ./build/tests/call-sync-repro/subscribe-unexported-object-arg-gate
 *
 * PASS → "spawned" notification with one arg, and a later call still works.
 * FAIL → OPC Subscription.emit does not export object args before write.
 */

class Child : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }
}

class Peer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }

	public signal void spawned(Child child);
}

class Gate : GLib.Object
{
	public static Peer? held_peer;
	public static Child? held_child;

	public static void rpc_register()
	{
		OLLMrpc.Bin.register("Gate-Peer", typeof(Peer));
		OLLMrpc.Bin.register("Gate-Child", typeof(Child));
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"make", "",
			"fire", "",
			"ping", "",
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
		/* Never exported on this connection. */
		Gate.held_child = new Child();
		stderr.printf("server: fire spawned(unexported child)\n");
		stderr.flush();
		Gate.held_peer.spawned(Gate.held_child);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}

	public void ping(OLLMrpc.Request request)
	{
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}
}

static void boot_rpc()
{
	OLLMrpc.rpc_register(true);
	Gsr.Server.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new Gsr.Server.Daemon());
	Gate.rpc_register();
}

static int run_server(string sock)
{
	boot_rpc();
	var listen = new Gsr.Server.Rpc.Listen(sock) {
		live_handles = true,
	};
	if (!listen.start()) {
		stderr.printf("FAIL subscribe-unexported-object-arg-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-subscribe-unexported-object-arg-gate-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(sock);

	GLib.Subprocess? server = null;
	try {
		server = new GLib.Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			GLib.SubprocessFlags.NONE
		);
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-unexported-object-arg-gate: spawn server %s\n", e.message);
		return 2;
	}

	var wait_deadline = GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < wait_deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)) {
		stderr.printf("FAIL subscribe-unexported-object-arg-gate: server socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "subscribe-unexported-object-arg-gate"),
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
		stderr.printf("FAIL subscribe-unexported-object-arg-gate: connect %s\n", connect_err);
		server.force_exit();
		return 2;
	}

	var got_spawned = false;
	var spawned_args = 0;
	client.notification.connect((notif) => {
		stderr.printf("client: notification method=%s id=%d args=%d\n",
			notif.method, notif.id, notif.args == null ? 0 : notif.args.size);
		stderr.flush();
		if (notif.method == "spawned") {
			got_spawned = true;
			spawned_args = notif.args == null ? 0 : notif.args.size;
		}
	});

	OLLMrpc.Response made;
	try {
		made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-unexported-object-arg-gate: make %s\n", e.message);
		server.force_exit();
		return 2;
	}
	var lid = made.args.get(0).get_uint64();

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Subscribe.rpc_signal",
			lease_id = lid,
			args = OLLMrpc.args("s", "spawned"),
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-unexported-object-arg-gate: subscribe %s\n", e.message);
		server.force_exit();
		return 2;
	}

	var fire_err = "";
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.fire",
		});
	} catch (GLib.Error e) {
		fire_err = e.message;
	}

	if (!got_spawned) {
		var wait = new GLib.MainLoop();
		GLib.Timeout.add(1000, () => {
			wait.quit();
			return GLib.Source.REMOVE;
		});
		wait.run();
	}

	var ping_err = "";
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.ping",
		});
	} catch (GLib.Error e) {
		ping_err = e.message;
	}

	server.force_exit();

	stderr.printf(
		"subscribe-unexported-object-arg-gate spawned=%s args=%d fire_err=%s ping_err=%s\n",
		got_spawned.to_string(), spawned_args,
		fire_err == "" ? "(none)" : fire_err,
		ping_err == "" ? "(none)" : ping_err
	);

	if (got_spawned && spawned_args == 1 && fire_err == "" && ping_err == "") {
		stderr.printf("PASS subscribe-unexported-object-arg-gate\n");
		return 0;
	}
	stderr.printf(
		"FAIL subscribe-unexported-object-arg-gate: signal with an unexported "
		+ "GObject arg did not arrive, or the connection dropped.\n"
	);
	return 1;
}
