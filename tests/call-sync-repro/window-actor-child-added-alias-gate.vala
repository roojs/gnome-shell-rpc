/**
 * Gate: the compositor adds ''MetaWindowActorWayland'' to
 * ''window_group'' before ''Meta.Display::window-created'' fires.
 *
 * When ''window_group'' has a ''child-added'' subscription,
 * ''OLLMrpc.Live.Subscription.emit'' writes that actor in a
 * ''Clutter.Actor''-typed ''GLib.Value''. If ''Meta-WindowActor''
 * has not been aliased to the private ''MetaWindowActorWayland''
 * GType yet, ''StreamValue.write'' encodes it as ''Clutter-Actor''.
 * The client caches a ''Clutter.Actor'' in ''client.proxies'', so
 * every later ''get_compositor_private() as WindowActor'' is null.
 *
 * {{{
 * meson compile -C build window-actor-child-added-alias-gate
 * timeout 5 ./build/tests/call-sync-repro/window-actor-child-added-alias-gate current
 * timeout 5 ./build/tests/call-sync-repro/window-actor-child-added-alias-gate fixed
 * }}}
 */

private class GateActor : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }

	public signal void child_added(GateActor actor);
}

private class GateWindowActor : GateActor
{
}

private class GateWindowActorWayland : GateWindowActor
{
}

private static bool alias_on_child_added = false;

private class ChildAddedAliasGate : GLib.Object
{
	private GateActor group { get; set; default = new GateActor(); }
	private GateWindowActorWayland window_actor {
		get; set; default = new GateWindowActorWayland();
	}

	public static void rpc_register(bool pre_alias)
	{
		OLLMrpc.Bin.register("Gate-Actor", typeof(GateActor));
		OLLMrpc.Bin.register("Gate-WindowActor", typeof(GateWindowActor));
		var instance = new ChildAddedAliasGate();
		if (pre_alias) {
			instance.group.child_added.connect((actor) => {
				if (actor is GateWindowActor
						&& !OLLMrpc.Bin.gtype_to_alias.has_key(actor.get_type())) {
					try {
						OLLMrpc.Bin.register_alias(
							"Gate-WindowActor", actor.get_type());
					} catch (GLib.Error e) {
						GLib.error("%s", e.message);
					}
				}
			});
		}
		OLLMrpc.Request.add_class(
			"ChildAddedAliasGate", typeof(ChildAddedAliasGate),
			"setup", "",
			"open_window", "",
			"get_compositor_private", "",
			null
		);
		OLLMrpc.Request.register_live("ChildAddedAliasGate", instance);
	}

	public void setup(OLLMrpc.Request request)
	{
		var lid = request.connection.export(this.group);
		this.group.rpc_lid = lid;
		var subscription = new OLLMrpc.Live.Subscription() {
			connection = request.connection,
			method = "child-added",
			id = (int) lid
		};
		if (!subscription.connect()) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("t", lid),
		});
	}

	public void open_window(OLLMrpc.Request request)
	{
		this.window_actor = new GateWindowActorWayland();
		/* mutter meta_compositor_add_window: add_child runs before
		 * display::window-created. */
		this.group.child_added(this.window_actor);
		/* Server.vala current order: display::window-created aliases
		 * after add_child already emitted child-added. */
		if (!alias_on_child_added
				&& !OLLMrpc.Bin.gtype_to_alias.has_key(
					this.window_actor.get_type())) {
			try {
				OLLMrpc.Bin.register_alias(
					"Gate-WindowActor", this.window_actor.get_type());
			} catch (GLib.Error e) {
				GLib.error("%s", e.message);
			}
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}

	public void get_compositor_private(OLLMrpc.Request request)
	{
		request.connection.export(this.window_actor);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("o", this.window_actor),
		});
	}
}

private static void boot_rpc(bool pre_alias)
{
	alias_on_child_added = pre_alias;
	OLLMrpc.rpc_register(true);
	Gsr.Server.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new Gsr.Server.Daemon());
	ChildAddedAliasGate.rpc_register(pre_alias);
}

private static int run_server(string socket_path, bool pre_alias)
{
	boot_rpc(pre_alias);
	var listener = new Gsr.Server.Rpc.Listen(socket_path) {
		live_handles = true,
	};
	if (!listener.start()) {
		GLib.stderr.printf("FAIL window-actor-child-added-alias-gate: listen\n");
		return 2;
	}
	new GLib.MainLoop().run();
	listener.stop();
	return 0;
}

int main(string[] args)
{
	var mode = "current";
	if (args.length >= 2 && args[1] != "server") {
		mode = args[1];
	}
	if (mode != "current" && mode != "fixed") {
		GLib.stderr.printf("FAIL window-actor-child-added-alias-gate: mode %s\n",
			mode);
		return 2;
	}
	if (args.length >= 3 && args[1] == "server") {
		return run_server(args[2], args.length >= 4 && args[3] == "fixed");
	}

	var self_path = args[0];
	try {
		self_path = GLib.FileUtils.read_link("/proc/self/exe");
	} catch (GLib.FileError e) {
		self_path = args[0];
	}

	var socket_path = "/tmp/gsr-window-actor-alias-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(socket_path);

	GLib.Subprocess server;
	try {
		server = new GLib.Subprocess.newv(
			{ self_path, "server", socket_path, mode },
			GLib.SubprocessFlags.NONE);
	} catch (GLib.Error e) {
		GLib.stderr.printf("FAIL window-actor-child-added-alias-gate: %s\n",
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
		GLib.stderr.printf("FAIL window-actor-child-added-alias-gate: no socket\n");
		return 2;
	}

	boot_rpc(false);
	var client = new OLLMrpc.Client("", "", socket_path) {
		live_handles = true,
		call_timeout_seconds = 3,
	};
	var loop = new GLib.MainLoop();
	var connected = false;
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "window-actor-child-added-alias-gate"),
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
		GLib.FileUtils.unlink(socket_path);
		GLib.stderr.printf("FAIL window-actor-child-added-alias-gate: connect\n");
		return 2;
	}

	GLib.Object? got = null;
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "ChildAddedAliasGate.setup",
		});
		client.call_poll(new OLLMrpc.Request() {
			method = "ChildAddedAliasGate.open_window",
		});
		var priv = client.call_poll(new OLLMrpc.Request() {
			method = "ChildAddedAliasGate.get_compositor_private",
		});
		if (priv.retval.type() != GLib.Type.INVALID) {
			got = priv.retval.get_object();
		}
	} catch (GLib.Error e) {
		server.force_exit();
		GLib.FileUtils.unlink(socket_path);
		GLib.stderr.printf("FAIL window-actor-child-added-alias-gate: %s\n",
			e.message);
		return 2;
	}

	server.force_exit();
	GLib.FileUtils.unlink(socket_path);

	var actor = got as GateWindowActor;
	if (actor == null) {
		var actual = got != null ? got.get_type().name() : "null";
		GLib.stderr.printf(
			"FAIL window-actor-child-added-alias-gate %s: got=%s\n",
			mode, actual);
		return 1;
	}
	GLib.stderr.printf(
		"PASS window-actor-child-added-alias-gate %s: got=%s\n",
		mode, actor.get_type().name());
	return 0;
}
