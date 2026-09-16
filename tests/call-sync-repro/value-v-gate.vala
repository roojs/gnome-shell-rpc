/**
 * Capital-V Value round-trip — OPC args("V") + Helper signature "V".
 *
 * Bug: OLLMchat docs/bugs/2026-09-16-bin-capital-v-value.md
 *
 *   meson compile -C build value-v-gate
 *   timeout 5 ./build/tests/call-sync-repro/value-v-gate
 */

class Gate : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"echo_value", "V",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	public void echo_value(OLLMrpc.Request request, GLib.Value held)
	{
		double num = 0.0;
		if (held.holds(typeof(float))) {
			num = held.get_float();
		} else if (held.holds(typeof(double))) {
			num = held.get_double();
		} else if (held.holds(typeof(int))) {
			num = held.get_int();
		} else {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("d", num),
			args = OLLMrpc.args("s", held.type().name() ?? ""),
		});
	}
}

static void boot_rpc()
{
	OLLMrpc.rpc_register(true);
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
		stderr.printf("FAIL value-v-gate server: listen %s\n", sock);
		stderr.flush();
		return 2;
	}
	new MainLoop().run();
	listen.stop();
	return 0;
}

static string self_exe(string argv0)
{
	try {
		return FileUtils.read_link("/proc/self/exe");
	} catch (FileError e) {
		return argv0;
	}
}

int main(string[] args)
{
	if (args.length >= 3 && args[1] == "server") {
		return run_server(args[2]);
	}

	var sock = "/tmp/gsr-value-v-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.STDERR_PIPE
		);
	} catch (Error e) {
		stderr.printf("FAIL value-v-gate: spawn %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL value-v-gate: socket missing\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 3,
	};

	var loop = new MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "value-v-gate"),
	}, null, (obj, res) => {
		try {
			connected = client.connect.end(res);
			if (!connected) {
				connect_err = client.connect_error;
			}
		} catch (Error e) {
			connect_err = e.message;
		}
		loop.quit();
	});
	loop.run();
	if (!connected) {
		stderr.printf("FAIL value-v-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	try {
		var held = GLib.Value(typeof(float));
		held.set_float(1.25f);
		var got = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.echo_value",
			args = OLLMrpc.args("V", held),
		});
		if (got.error != null) {
			stderr.printf("FAIL value-v-gate: echo error\n");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 1;
		}
		double num = got.retval.holds(typeof(double))
			? got.retval.get_double()
			: got.retval.get_float();
		if (Math.fabs(num - 1.25) > 1e-6) {
			stderr.printf(
				"FAIL value-v-gate: payload=%g want 1.25\n", num);
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 1;
		}
		var want_type = GLib.Type.FLOAT.name() ?? "gfloat";
		if (got.args.size < 1
				|| got.args.get(0).get_string() != want_type) {
			stderr.printf(
				"FAIL value-v-gate: type name want %s got %s\n",
				want_type,
				got.args.size > 0
					? (got.args.get(0).get_string() ?? "(null)")
					: "(missing)");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 1;
		}
	} catch (Error e) {
		stderr.printf("FAIL value-v-gate: %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	server.force_exit();
	FileUtils.unlink(sock);
	stderr.printf(
		"PASS value-v-gate: capital-V Value type+data round-trip\n");
	stderr.flush();
	return 0;
}
