/**
 * A server notify is applied with proxy.set_property(). The generated
 * setter stores the value and returns before call_poll when it already
 * matches. The server peer notifies on every set, including the same
 * value, so the echo does not die on the server.
 *
 *   meson compile -C build tests/call-sync-repro/notify-proxy-setter-echo-gate
 *   timeout 5 ./build/tests/call-sync-repro/notify-proxy-setter-echo-gate
 *
 * PASS -> one real change sends one setter RPC. The notify of that
 * value, and a later set of that value, send nothing more.
 * FAIL -> the setter RPCs the echo and the server notify loops.
 */

class ServerPeer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }
	private bool stored_visible = false;
	private double stored_level = 0;

	public bool visible {
		get {
			return this.stored_visible;
		}
		set {
			this.stored_visible = value;
			this.notify_property("visible");
		}
	}

	public double level {
		get {
			return this.stored_level;
		}
		set {
			this.stored_level = value;
			this.notify_property("level");
		}
	}
}

class ClientProxy : GLib.Object, OLLMrpc.Live.Interface
{
	public static int outbound_sets = 0;
	public static int depth = 0;
	public static OLLMrpc.Client? rpc;
	private bool stored_visible = false;
	private double stored_level = 0;

	public uint64 rpc_lid { get; set construct; default = 0; }

	public bool visible {
		get {
			return this.stored_visible;
		}
		set {
			if (this.stored_visible == value) {
				return;
			}
			this.stored_visible = value;
			this.send("EchoGate.set_visible", OLLMrpc.args("b", value));
		}
	}

	public double level {
		get {
			return this.stored_level;
		}
		set {
			if (this.stored_level == value) {
				return;
			}
			this.stored_level = value;
			this.send("EchoGate.set_level", OLLMrpc.args("d", value));
		}
	}

	private void send(string method, Gee.ArrayList<GLib.Value?> args)
	{
		if (ClientProxy.depth > 2) {
			stderr.printf("FAIL notify-proxy-setter-echo-gate: setter recursed\n");
			GLib.error("notify echo recursed");
		}
		ClientProxy.outbound_sets++;
		ClientProxy.depth++;
		try {
			ClientProxy.rpc.call_poll(new OLLMrpc.Request() {
				method = method,
				args = args,
			});
		} catch (GLib.Error e) {
			stderr.printf("FAIL notify-proxy-setter-echo-gate: %s %s\n", method, e.message);
			GLib.error("%s", e.message);
		}
		ClientProxy.depth--;
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
			"set_visible", "",
			"set_level", "",
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

	public void set_visible(OLLMrpc.Request request)
	{
		if (EchoGate.peer == null || request.args.size < 1) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		EchoGate.peer.visible = request.args.get(0).get_boolean();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}

	public void set_level(OLLMrpc.Request request)
	{
		if (EchoGate.peer == null || request.args.size < 1) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		EchoGate.peer.level = request.args.get(0).get_double();
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
	ClientProxy.rpc = client;
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

	var got_visible = false;
	var got_level = false;
	client.notification.connect((notif) => {
		if (notif.method == "notify::visible"
				&& notif.args.size == 1
				&& notif.args.get(0).holds(GLib.Type.BOOLEAN)
				&& notif.args.get(0).get_boolean()) {
			got_visible = true;
		}
		if (notif.method == "notify::level"
				&& notif.args.size == 1
				&& notif.args.get(0).holds(GLib.Type.DOUBLE)
				&& notif.args.get(0).get_double() == 1.5) {
			got_level = true;
		}
	});

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Subscribe.rpc_signal",
			lease_id = lid,
			args = OLLMrpc.args("s", "notify::visible"),
		});
		client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Subscribe.rpc_signal",
			lease_id = lid,
			args = OLLMrpc.args("s", "notify::level"),
		});
	} catch (GLib.Error e) {
		server.force_exit();
		stderr.printf("FAIL notify-proxy-setter-echo-gate: subscribe %s\n", e.message);
		return 2;
	}

	ClientProxy.outbound_sets = 0;
	proxy.visible = true;
	if (!got_visible || ClientProxy.outbound_sets != 1) {
		server.force_exit();
		stderr.printf(
			"FAIL notify-proxy-setter-echo-gate: visible notify=%s outbound=%d\n",
			got_visible ? "yes" : "no",
			ClientProxy.outbound_sets);
		return 1;
	}
	proxy.visible = true;
	if (ClientProxy.outbound_sets != 1) {
		server.force_exit();
		stderr.printf(
			"FAIL notify-proxy-setter-echo-gate: same visible sent %d\n",
			ClientProxy.outbound_sets);
		return 1;
	}

	ClientProxy.outbound_sets = 0;
	proxy.level = 1.5;
	if (!got_level || ClientProxy.outbound_sets != 1) {
		server.force_exit();
		stderr.printf(
			"FAIL notify-proxy-setter-echo-gate: level notify=%s outbound=%d\n",
			got_level ? "yes" : "no",
			ClientProxy.outbound_sets);
		return 1;
	}
	proxy.level = 1.5;
	if (ClientProxy.outbound_sets != 1) {
		server.force_exit();
		stderr.printf(
			"FAIL notify-proxy-setter-echo-gate: same level sent %d\n",
			ClientProxy.outbound_sets);
		return 1;
	}

	server.force_exit();
	stderr.printf("PASS notify-proxy-setter-echo-gate\n");
	return 0;
}
