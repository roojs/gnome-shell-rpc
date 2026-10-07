/**
 * Gate: a live GObject must use its declared GValue type on the wire.
 *
 * An unregistered private leaf uses its declared public GValue type. An
 * exact runtime alias remains more specific than a broad declared base:
 * Meta.Backend.get_stage is declared Clutter.Actor, but its MetaStageX11
 * runtime type is explicitly aliased to Clutter.Stage.
 *
 * No OPC edits from this tree.
 *
 *   meson compile -C build declared-object-type-gate
 *   timeout 5 ./build/tests/call-sync-repro/declared-object-type-gate
 *
 * FAIL → OPC discarded either the declaration or the exact alias.
 * PASS → both public proxy types arrive and a later ping still replies.
 */

class GateBase : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }
}

class GatePublic : GateBase
{
}

class GateUnregistered : GatePublic
{
}

class GateAliasedPrivate : GatePublic
{
}

class DeclaredTypeGate : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Bin.register("Gate-Base", typeof(GateBase));
		OLLMrpc.Bin.register("Gate-Public", typeof(GatePublic));
		OLLMrpc.Bin.register_alias(
			"Gate-Public", typeof(GateAliasedPrivate));
		OLLMrpc.Request.add_class(
			"DeclaredTypeGate", typeof(DeclaredTypeGate),
			"make_declared", "",
			"make_aliased", "",
			"ping", "",
			null
		);
		OLLMrpc.Request.register_live(
			"DeclaredTypeGate", new DeclaredTypeGate());
	}

	public void make_declared(OLLMrpc.Request request)
	{
		var object = new GateUnregistered();
		request.connection.export(object);
		var declared = GLib.Value(typeof(GatePublic));
		declared.set_object(object);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = declared,
		});
	}

	public void make_aliased(OLLMrpc.Request request)
	{
		var object = new GateAliasedPrivate();
		request.connection.export(object);
		var declared = GLib.Value(typeof(GateBase));
		declared.set_object(object);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = declared,
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
	DeclaredTypeGate.rpc_register();
}

static int run_server(string socket_path)
{
	boot_rpc();
	var listen = new Gsr.Server.Rpc.Listen(socket_path) {
		live_handles = true,
	};
	if (!listen.start()) {
		stderr.printf(
			"FAIL declared-object-type-gate server: listen %s\n",
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

	var socket_path = "/tmp/gsr-declared-object-type-gate-%d.sock".printf(
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
			"FAIL declared-object-type-gate: spawn server %s\n",
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
			"FAIL declared-object-type-gate: server socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "declared-object-type-gate"),
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
			"FAIL declared-object-type-gate: connect %s\n",
			connect_error);
		stderr.flush();
		server.force_exit();
		GLib.FileUtils.unlink(socket_path);
		return 2;
	}

	try {
		var declared = client.call_poll(new OLLMrpc.Request() {
			method = "DeclaredTypeGate.make_declared",
		});
		var declared_object = declared.retval.get_object() as GatePublic;
		if (declared_object == null || declared_object.rpc_lid == 0) {
			stderr.printf(
				"FAIL declared-object-type-gate: "
				+ "declared GatePublic lease missing\n");
			stderr.flush();
			server.force_exit();
			GLib.FileUtils.unlink(socket_path);
			return 1;
		}
		var aliased = client.call_poll(new OLLMrpc.Request() {
			method = "DeclaredTypeGate.make_aliased",
		});
		var aliased_object = aliased.retval.get_object() as GatePublic;
		if (aliased_object == null || aliased_object.rpc_lid == 0) {
			stderr.printf(
				"FAIL declared-object-type-gate: "
				+ "exact GatePublic alias lost to declared GateBase\n");
			stderr.flush();
			server.force_exit();
			GLib.FileUtils.unlink(socket_path);
			return 1;
		}
		var ping = client.call_poll(new OLLMrpc.Request() {
			method = "DeclaredTypeGate.ping",
		});
		if (!ping.retval.get_boolean()) {
			stderr.printf(
				"FAIL declared-object-type-gate: ping was false\n");
			stderr.flush();
			server.force_exit();
			GLib.FileUtils.unlink(socket_path);
			return 1;
		}
		stderr.printf(
			"PASS declared-object-type-gate: "
			+ "declared fallback and exact alias preserved\n");
		stderr.flush();
	} catch (GLib.Error e) {
		stderr.printf(
			"FAIL declared-object-type-gate: %s "
			+ "(declared fallback or exact alias was discarded)\n",
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
