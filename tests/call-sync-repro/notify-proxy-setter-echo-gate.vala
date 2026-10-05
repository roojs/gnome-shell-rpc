/**
 * FAIL gate: applying a server notify to a client Live proxy must not call the
 * proxy's public setter. Generated gnome-shell-rpc setters send an RPC, so
 * Client.set_property() echoes notify::value back to the server forever.
 *
 *   meson compile -C build notify-proxy-setter-echo-gate
 *   timeout 5 ./build/tests/call-sync-repro/notify-proxy-setter-echo-gate
 *
 * PASS -> typed notify arrives and the outbound proxy setter is not called.
 * FAIL -> libocrpc Client applies notify with proxy.set_property().
 */

class ServerPeer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }
	public bool visible { get; set; default = false; }
}

class ClientProxy : GLib.Object, OLLMrpc.Live.Interface
{
	public static int outbound_sets = 0;
	private bool stored_visible = false;

	public uint64 rpc_lid { get; set construct; default = 0; }

	public bool visible {
		get {
			return this.stored_visible;
		}
		set {
			ClientProxy.outbound_sets++;
			this.stored_visible = value;
		}
	}
}

class EchoGate : GLib.Object
{
	public static ServerPeer? peer;

	public static void rpc_register()
	{
		OLLMrpc.Bin.register("EchoGate-ServerPeer", typeof(ServerPeer));
		OLLMrpc.Request.add_class(
			"EchoGate", typeof(EchoGate),
			"make", "",
			"show", "",
			null
		);
		OLLMrpc.Request.register_live("EchoGate", new EchoGate());
	}

	public void make(OLLMrpc.Request request)
	{
		var made = new ServerPeer();
		var lid = request.connection.export(made);
		made.rpc_lid = lid;
		EchoGate.peer = made;
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("t", lid),
		});
	}

	public void show(OLLMrpc.Request request)
	{
		if (EchoGate.peer == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		EchoGate.peer.visible = true;
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
	EchoGate.rpc_register();
}

static int run_server(string sock)
{
	boot_rpc();
	var listen = new Gsr.Server.Rpc.Listen(sock) {
		live_handles = true,
	};
	if (!listen.start()) {
		stderr.printf("FAIL notify-proxy-setter-echo-gate server: listen\n");
		return 2;
	}
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

	var sock = "/tmp/gsr-notify-proxy-setter-echo-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(sock);

	GLib.Subprocess server;
	try {
		server = new GLib.Subprocess.newv(
			{ self_exe(args[0]), "server", sock },
			GLib.SubprocessFlags.NONE
		);
	} catch (GLib.Error e) {
		stderr.printf("FAIL notify-proxy-setter-echo-gate: spawn %s\n", e.message);
		return 2;
	}

	var deadline = GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)) {
		server.force_exit();
		stderr.printf("FAIL notify-proxy-setter-echo-gate: no socket\n");
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 3,
	};
	var loop = new GLib.MainLoop();
	var connected = false;
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "notify-proxy-setter-echo-gate"),
	}, null, (obj, res) => {
		try {
			connected = client.connect.end(res);
		} catch (GLib.Error e) {
			stderr.printf("connect: %s\n", e.message);
		}
		loop.quit();
	});
	loop.run();
	if (!connected) {
		server.force_exit();
		stderr.printf("FAIL notify-proxy-setter-echo-gate: connect\n");
		return 2;
	}

	uint64 lid;
	try {
		var made = client.call_poll(new OLLMrpc.Request() {
			method = "EchoGate.make",
		});
		lid = made.args.get(0).get_uint64();
	} catch (GLib.Error e) {
		server.force_exit();
		stderr.printf("FAIL notify-proxy-setter-echo-gate: make %s\n", e.message);
		return 2;
	}

	var proxy = new ClientProxy() {
		rpc_lid = lid,
	};
	client.proxies.set((int) lid, proxy);
	ClientProxy.outbound_sets = 0;

	var got_typed_notify = false;
	client.notification.connect((notif) => {
		if (notif.method == "notify::visible"
				&& notif.args.size == 1
				&& notif.args.get(0).holds(GLib.Type.BOOLEAN)
				&& notif.args.get(0).get_boolean()) {
			got_typed_notify = true;
		}
	});

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Subscribe.rpc_signal",
			lease_id = lid,
			args = OLLMrpc.args("s", "notify::visible"),
		});
		client.call_poll(new OLLMrpc.Request() {
			method = "EchoGate.show",
		});
	} catch (GLib.Error e) {
		server.force_exit();
		stderr.printf("FAIL notify-proxy-setter-echo-gate: call %s\n", e.message);
		return 2;
	}

	server.force_exit();
	if (!got_typed_notify) {
		stderr.printf("FAIL notify-proxy-setter-echo-gate: notify missing\n");
		return 1;
	}
	if (ClientProxy.outbound_sets != 0) {
		stderr.printf(
			"FAIL notify-proxy-setter-echo-gate: notify called outbound setter %d time(s)\n",
			ClientProxy.outbound_sets);
		return 1;
	}

	stderr.printf("PASS notify-proxy-setter-echo-gate\n");
	return 0;
}
