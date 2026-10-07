/**
 * Gate: a compositor effect returned to the client must unpack.
 *
 * {@code get_effect} is declared {@code Clutter.Effect}. An unregistered
 * peer encodes as that declared type. Registering the peer as
 * {@code Shell-BlurEffect}, or aliasing it to {@code Clutter-Effect},
 * is a different claim. This gate leaves the leaf unregistered.
 *
 * This process is that registration and that return. It does not link
 * {@code BlurEffect} (that class needs a Cogl context).
 *
 *   meson compile -C build tests/call-sync-repro/shell-blur-alias-gate
 *   timeout 5 ./build/tests/call-sync-repro/shell-blur-alias-gate
 *
 * FAIL → the return was not the public effect type.
 * PASS → the return arrived as {@code Clutter-Effect}.
 */

class EffectPublic : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }
}

class EffectBlur : EffectPublic
{
}

class BlurAliasGate : GLib.Object
{
	public static void rpc_register_server()
	{
		OLLMrpc.Bin.register("Clutter-Effect", typeof(EffectPublic));
		OLLMrpc.Request.add_class(
			"BlurAliasGate", typeof(BlurAliasGate),
			"make", "",
			null
		);
		OLLMrpc.Request.register_live(
			"BlurAliasGate", new BlurAliasGate());
	}

	public static void rpc_register_client()
	{
		OLLMrpc.Bin.register("Clutter-Effect", typeof(EffectPublic));
	}

	public void make(OLLMrpc.Request request)
	{
		var effect = new EffectBlur();
		request.connection.export(effect);
		var declared = GLib.Value(typeof(EffectPublic));
		declared.set_object(effect);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = declared,
		});
	}
}

static void boot_common()
{
	OLLMrpc.rpc_register(true);
	Gsr.Server.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new Gsr.Server.Daemon());
}

static int run_server(string socket_path)
{
	boot_common();
	BlurAliasGate.rpc_register_server();
	var listen = new Gsr.Server.Rpc.Listen(socket_path) {
		live_handles = true,
	};
	if (!listen.start()) {
		stderr.printf(
			"FAIL shell-blur-alias-gate server: listen %s\n",
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

	var socket_path = "/tmp/gsr-shell-blur-alias-gate-%d.sock".printf(
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
			"FAIL shell-blur-alias-gate: spawn server %s\n",
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
			"FAIL shell-blur-alias-gate: server socket never appeared\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_common();
	BlurAliasGate.rpc_register_client();
	var client = new OLLMrpc.Client("", "", socket_path) {
		live_handles = true,
		call_timeout_seconds = 3,
	};
	var loop = new GLib.MainLoop();
	var connected = false;
	var connect_error = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "shell-blur-alias-gate"),
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
			"FAIL shell-blur-alias-gate: connect %s\n",
			connect_error);
		stderr.flush();
		server.force_exit();
		GLib.FileUtils.unlink(socket_path);
		return 2;
	}

	try {
		var made = client.call_poll(new OLLMrpc.Request() {
			method = "BlurAliasGate.make",
		});
		var effect = made.retval.get_object() as EffectPublic;
		if (effect == null || effect.rpc_lid == 0) {
			stderr.printf(
				"FAIL shell-blur-alias-gate: public effect lease missing\n");
			stderr.flush();
			server.force_exit();
			GLib.FileUtils.unlink(socket_path);
			return 1;
		}
		stderr.printf(
			"PASS shell-blur-alias-gate: effect unpacked\n");
		stderr.flush();
	} catch (GLib.Error e) {
		stderr.printf("FAIL shell-blur-alias-gate: %s\n", e.message);
		stderr.flush();
		server.force_exit();
		GLib.FileUtils.unlink(socket_path);
		return 1;
	}

	server.force_exit();
	GLib.FileUtils.unlink(socket_path);
	return 0;
}
