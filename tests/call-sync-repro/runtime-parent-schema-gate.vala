/**
 * Gate: val("o") of an unregistered private subclass must cross as the
 * nearest registered parent.
 *
 * declared-object-type-gate covers a GValue already typed as the public
 * class. This is the other pack: OLLMrpc.val("o", obj) stamps
 * obj.get_type(). MetaSurfaceActorWayland on the event filter is that
 * shape. The wire class is the nearest registered parent. An exact
 * runtime alias still wins over that parent.
 *
 * No OPC edits from this tree.
 *
 *   meson compile -C build runtime-parent-schema-gate
 *   timeout 5 ./build/tests/call-sync-repro/runtime-parent-schema-gate
 *
 * FAIL → OPC disconnects on the unregistered runtime type.
 * PASS → GatePublic arrives for both arms and a later ping still replies.
 */

class GatePublic : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }
}

class GateUnregistered : GatePublic
{
}

class GateAliasedPrivate : GatePublic
{
}

class RuntimeParentGate : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Bin.register("Gate-Public", typeof(GatePublic));
		OLLMrpc.Bin.register_alias(
			"Gate-Public", typeof(GateAliasedPrivate));
		OLLMrpc.Request.add_class(
			"RuntimeParentGate", typeof(RuntimeParentGate),
			"make_runtime", "",
			"make_aliased", "",
			"ping", "",
			null
		);
		OLLMrpc.Request.register_live(
			"RuntimeParentGate", new RuntimeParentGate());
	}

	public void make_runtime(OLLMrpc.Request request)
	{
		var object = new GateUnregistered();
		request.connection.export(object);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("o", object),
		});
	}

	public void make_aliased(OLLMrpc.Request request)
	{
		var object = new GateAliasedPrivate();
		request.connection.export(object);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("o", object),
		});
	}

	public void ping(OLLMrpc.Request request)
	{
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("b", true),
		});
	}
}

static void boot_rpc()
{
	OLLMrpc.rpc_register(true);
	Gsr.Server.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new Gsr.Server.Daemon());
	RuntimeParentGate.rpc_register();
}

static int run_server(string socket_path)
{
	boot_rpc();
	var listen = new Gsr.Server.Rpc.Listen(socket_path) {
		live_handles = true,
	};
	if (!listen.start()) {
		stderr.printf(
			"FAIL runtime-parent-schema-gate server: listen %s\n",
			socket_path);
		stderr.flush();
		return 2;
	}
	new GLib.MainLoop().run();
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

	var socket_path = "/tmp/gsr-runtime-parent-schema-gate-%d.sock".printf(
		(int) (GLib.get_monotonic_time() & 0x7fffffff));
	GLib.FileUtils.unlink(socket_path);

	GLib.Subprocess server;
	try {
		server = new GLib.Subprocess.newv(
			{self_exe(args[0]), "server", socket_path},
			GLib.SubprocessFlags.NONE
		);
	} catch (GLib.Error e) {
		stderr.printf(
			"FAIL runtime-parent-schema-gate: spawn server %s\n",
			e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline =
		GLib.get_monotonic_time() + 2 * GLib.TimeSpan.SECOND;
	while (!GLib.FileUtils.test(socket_path, GLib.FileTest.EXISTS)
			&& GLib.get_monotonic_time() < wait_deadline) {
		GLib.Thread.usleep(10000);
	}
	if (!GLib.FileUtils.test(socket_path, GLib.FileTest.EXISTS)) {
		stderr.printf(
			"FAIL runtime-parent-schema-gate: server socket never appeared\n");
		stderr.flush();
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
	var connect_error = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "runtime-parent-schema-gate"),
	}, null, (obj, res) => {
		try {
			connected = client.connect.end(res);
			if (!connected) {
				connect_error = client.connect_error;
			}
		} catch (GLib.Error e) {
			connect_error = e.message;
		}
		loop.quit();
	});
	loop.run();
	if (!connected) {
		stderr.printf(
			"FAIL runtime-parent-schema-gate: connect %s\n",
			connect_error);
		stderr.flush();
		server.force_exit();
		GLib.FileUtils.unlink(socket_path);
		return 2;
	}

	try {
		var runtime = client.call_poll(new OLLMrpc.Request() {
			method = "RuntimeParentGate.make_runtime",
		});
		var runtime_object = runtime.retval.get_object() as GatePublic;
		if (runtime_object == null || runtime_object.rpc_lid == 0) {
			stderr.printf(
				"FAIL runtime-parent-schema-gate: "
				+ "unregistered runtime type did not arrive as GatePublic\n");
			stderr.flush();
			server.force_exit();
			GLib.FileUtils.unlink(socket_path);
			return 1;
		}
		var aliased = client.call_poll(new OLLMrpc.Request() {
			method = "RuntimeParentGate.make_aliased",
		});
		var aliased_object = aliased.retval.get_object() as GatePublic;
		if (aliased_object == null || aliased_object.rpc_lid == 0) {
			stderr.printf(
				"FAIL runtime-parent-schema-gate: "
				+ "exact GatePublic alias lost\n");
			stderr.flush();
			server.force_exit();
			GLib.FileUtils.unlink(socket_path);
			return 1;
		}
		var ping = client.call_poll(new OLLMrpc.Request() {
			method = "RuntimeParentGate.ping",
		});
		if (!ping.retval.get_boolean()) {
			stderr.printf(
				"FAIL runtime-parent-schema-gate: ping was false\n");
			stderr.flush();
			server.force_exit();
			GLib.FileUtils.unlink(socket_path);
			return 1;
		}
		stderr.printf(
			"PASS runtime-parent-schema-gate: "
			+ "unregistered parent and exact alias preserved\n");
		stderr.flush();
	} catch (GLib.Error e) {
		stderr.printf(
			"FAIL runtime-parent-schema-gate: %s "
			+ "(unregistered runtime type disconnected)\n",
			e.message);
		stderr.flush();
		server.force_exit();
		GLib.FileUtils.unlink(socket_path);
		return 1;
	}

	server.force_exit();
	GLib.FileUtils.unlink(socket_path);
	return 0;
}
