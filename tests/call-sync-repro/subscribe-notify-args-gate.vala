/**
 * Gate: {@code notify::} must deliver the property value on
 * {@link OLLMrpc.Notification.args}, typed, with {@code message} empty.
 *
 * A boolean property cannot ride in {@code Notification.message}.
 * {@code allocation} ({@code ClutterActorBox}) and {@code visible}
 * ({@code gboolean}) fail that string read and string {@code set_property}.
 *
 *   meson compile -C build subscribe-notify-args-gate
 *   timeout 5 ./build/tests/call-sync-repro/subscribe-notify-args-gate
 *
 * PASS → {@code notify::visible} has {@code args[0] == true} and empty message,
 *        and {@code notify::stamp} uses the registered {@link OLLMrpc.Bin.TypeOverride}
 *        (ISO-8601 string) without closing the connection.
 * FAIL → {@code notify::} writes the raw boxed value and ignores the override.
 *        File in OLLMchat {@code docs/bugs/}. Do not add a DateTime encoder in
 *        gnome-shell-rpc.
 */

class StampOverride : OLLMrpc.Bin.TypeOverride
{
	public override GLib.Type override_type {
		get {
			return typeof(GLib.DateTime);
		}
	}

	public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
	{
		var dt = (GLib.DateTime) src.get_boxed();
		return OLLMrpc.args("s", dt.to_utc().format_iso8601());
	}

	public override GLib.Value unpack(
		Gee.ArrayList<GLib.Value?> fields,
		int index,
		out int consumed
	) {
		consumed = 1;
		var copy = GLib.Value(typeof(string));
		if (index < fields.size && fields.get(index) != null
				&& fields.get(index).holds(GLib.Type.STRING)) {
			copy.set_string(fields.get(index).get_string());
		}
		return copy;
	}
}

class Peer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }
	public bool visible { get; set; default = false; }
	public GLib.DateTime? stamp { get; set; }

	public void show()
	{
		this.visible = true;
	}

	public void mark()
	{
		this.stamp = new GLib.DateTime.now_utc();
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
			"show", "",
			"mark", "",
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

	public void show(OLLMrpc.Request request)
	{
		if (Gate.held_peer == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		Gate.held_peer.show();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}

	public void mark(OLLMrpc.Request request)
	{
		if (Gate.held_peer == null) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		Gate.held_peer.mark();
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
	OLLMrpc.Bin.TypeOverride.register(new StampOverride());
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
		stderr.printf("FAIL subscribe-notify-args-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-subscribe-notify-args-gate-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(sock);

	GLib.Subprocess? server = null;
	try {
		server = new GLib.Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			GLib.SubprocessFlags.NONE
		);
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-notify-args-gate: spawn server %s\n", e.message);
		return 2;
	}

	var wait_deadline = GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < wait_deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(sock, GLib.FileTest.EXISTS)) {
		stderr.printf("FAIL subscribe-notify-args-gate: server socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "subscribe-notify-args-gate"),
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
		stderr.printf("FAIL subscribe-notify-args-gate: connect %s\n", connect_err);
		server.force_exit();
		return 2;
	}

	string? got_method = null;
	bool got_visible = false;
	string got_message = "";
	int got_args = -1;
	client.notification.connect((notif) => {
		var holds_bool = false;
		var value = false;
		if (notif.args != null && notif.args.size > 0
				&& notif.args.get(0) != null
				&& notif.args.get(0).holds(GLib.Type.BOOLEAN)) {
			holds_bool = true;
			value = notif.args.get(0).get_boolean();
		}
		stderr.printf(
			"client: notification method=%s id=%d args=%d bool=%s message=%s\n",
			notif.method, notif.id,
			notif.args == null ? 0 : notif.args.size,
			holds_bool ? value.to_string() : "(not bool)",
			notif.message
		);
		stderr.flush();
		if (notif.method == "notify::visible") {
			got_method = notif.method;
			got_visible = holds_bool && value;
			got_message = notif.message;
			got_args = notif.args == null ? 0 : notif.args.size;
		}
	});

	OLLMrpc.Response made;
	try {
		made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-notify-args-gate: make %s\n", e.message);
		server.force_exit();
		return 2;
	}
	if (made.args.size < 1) {
		stderr.printf("FAIL subscribe-notify-args-gate: make no lease\n");
		server.force_exit();
		return 2;
	}
	var lid = made.args.get(0).get_uint64();

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Subscribe.rpc_signal",
			lease_id = lid,
			args = OLLMrpc.args("s", "notify::visible"),
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-notify-args-gate: subscribe %s\n", e.message);
		server.force_exit();
		return 2;
	}

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.show",
		});
	} catch (GLib.Error e) {
		stderr.printf("FAIL subscribe-notify-args-gate: show %s\n", e.message);
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

	stderr.printf(
		"subscribe-notify-args-gate method=%s args=%d visible=%s message=%s\n",
		got_method ?? "(none)",
		got_args,
		got_visible ? "true" : "false",
		got_message
	);

	if (!(got_method == "notify::visible" && got_visible && got_message == "")) {
		server.force_exit();
		stderr.printf(
			"FAIL subscribe-notify-args-gate: notify::visible did not arrive "
			+ "as a boolean on Notification.args with an empty message.\n"
		);
		return 1;
	}

	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Subscribe.rpc_signal",
			lease_id = lid,
			args = OLLMrpc.args("s", "notify::stamp"),
		});
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.mark",
		});
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.ping",
		});
	} catch (GLib.Error e) {
		server.force_exit();
		stderr.printf(
			"FAIL subscribe-notify-args-gate: notify of boxed property "
			+ "closed the connection: %s\n",
			e.message
		);
		return 1;
	}

	server.force_exit();
	stderr.printf("PASS subscribe-notify-args-gate\n");
	return 0;
}
