/**
 * DING calls subprocess.wait_async on a process that stays running.
 * Meta.RpcSubprocess.wait_async uses call_value → call_poll, which
 * blocks and does not iterate the default main context, so extension
 * timeouts never run. The yield mode uses OLLMrpc.Client.call instead.
 *
 *   timeout 5 ./build/tests/call-sync-repro/wayland-wait-blocks-gate
 *   timeout 5 ./build/tests/call-sync-repro/wayland-wait-blocks-gate yield
 */

private class Gate : GLib.Object
{
	private static OLLMrpc.Request? held = null;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"wait", "",
			"release", "",
			null);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	public void wait(OLLMrpc.Request request)
	{
		Gate.held = request;
	}

	public void release(OLLMrpc.Request request)
	{
		var waiting = Gate.held;
		Gate.held = null;
		if (waiting != null) {
			waiting.reply(new OLLMrpc.Response() {
				id = waiting.id,
				retval = OLLMrpc.val("b", true),
			});
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
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

private static int run_blocking(OLLMrpc.Client client)
{
	var main_ran = false;
	GLib.Timeout.add(200, () => {
		main_ran = true;
		return false;
	});
	var started = GLib.get_monotonic_time();
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.wait",
		});
	} catch (GLib.Error e) {
	}
	var elapsed_ms = (GLib.get_monotonic_time() - started) / 1000;
	if (!main_ran && elapsed_ms >= 800) {
		stderr.printf(
			"FAIL wayland-wait-blocks-gate: default timeout did not run during call_poll (%lld ms)\n",
			elapsed_ms);
		return 1;
	}
	stderr.printf(
		"PASS wayland-wait-blocks-gate: unexpected main_ran=%s elapsed=%lld ms\n",
		main_ran.to_string(), elapsed_ms);
	return 0;
}

private static int run_yield(OLLMrpc.Client client)
{
	var loop = new GLib.MainLoop();
	var main_ran = false;
	var wait_done = false;
	var wait_ok = false;
	client.call.begin(new OLLMrpc.Request() {
		method = "Gate.wait",
	}, (obj, res) => {
		try {
			var response = client.call.end(res);
			wait_ok = response.retval.get_boolean();
		} catch (GLib.Error e) {
			wait_ok = false;
		}
		wait_done = true;
		loop.quit();
	});
	GLib.Timeout.add(200, () => {
		main_ran = true;
		/* force_exit is call_poll: it must go out while wait is still
		 * the head of Client.call's queue, or the process never dies. */
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "Gate.release",
			});
		} catch (GLib.Error e) {
		}
		return false;
	});
	GLib.Timeout.add_seconds(2, () => {
		loop.quit();
		return false;
	});
	loop.run();
	if (main_ran && wait_done && wait_ok) {
		stderr.printf(
			"PASS wayland-wait-blocks-gate: default timeout ran while wait was outstanding\n");
		return 0;
	}
	stderr.printf(
		"FAIL wayland-wait-blocks-gate: main_ran=%s wait_done=%s wait_ok=%s\n",
		main_ran.to_string(), wait_done.to_string(), wait_ok.to_string());
	return 1;
}

int main(string[] args)
{
	if (args.length >= 3 && args[1] == "server") {
		return run_server(args[2]);
	}
	var yield_mode = args.length >= 2 && args[1] == "yield";
	var socket_path = "/tmp/gsr-wayland-wait-blocks-%d.sock".printf(
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
		call_timeout_seconds = 1,
	};
	var loop = new GLib.MainLoop();
	var connected = false;
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "wayland-wait-blocks-gate"),
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

	var code = yield_mode ? run_yield(client) : run_blocking(client);
	server.force_exit();
	GLib.FileUtils.unlink(socket_path);
	return code;
}
