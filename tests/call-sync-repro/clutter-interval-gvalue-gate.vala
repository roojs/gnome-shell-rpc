/**
 * External prove: Clutter.Interval.set_final (typelib name; C
 * set_final_value) over Gi with held Value in Request.args — not
 * ay-memcpy of the GValue struct.
 *
 * No gi-stub, no generator, no Transition override. FAIL → OPC.
 * PASS → generator may pack GObject.Value the same way.
 *
 *   meson compile -C build clutter-interval-gvalue-gate
 *   timeout 5 ./build/tests/call-sync-repro/clutter-interval-gvalue-gate
 */

static void clutter_env()
{
	var tip = Environment.get_variable("GI_TYPELIB_PATH");
	var mutter_tl = "/usr/lib/x86_64-linux-gnu/mutter-16";
	if (tip == null || tip == "") {
		Environment.set_variable("GI_TYPELIB_PATH", mutter_tl, true);
	} else if (!tip.contains(mutter_tl)) {
		Environment.set_variable(
			"GI_TYPELIB_PATH", mutter_tl + ":" + tip, true);
	}
	var ld = Environment.get_variable("LD_LIBRARY_PATH");
	if (ld == null || ld == "") {
		Environment.set_variable("LD_LIBRARY_PATH", mutter_tl, true);
	} else if (!ld.contains(mutter_tl)) {
		Environment.set_variable(
			"LD_LIBRARY_PATH", mutter_tl + ":" + ld, true);
	}
}

class Gate : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"make_interval", "",
			"peek_final", "t",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	public void make_interval(OLLMrpc.Request request)
	{
		var from = GLib.Value(typeof(double));
		from.set_double(0.0);
		var to = GLib.Value(typeof(double));
		to.set_double(1.0);
		var interval = new Clutter.Interval.with_values(
			typeof(double), from, to);
		var lid = request.connection.export(interval);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("t", (uint64) lid),
		});
	}

	public void peek_final(OLLMrpc.Request request, uint64 lid)
	{
		if (!request.connection.leases.has_key((int) lid)) {
			request.connection.reply_error(
				request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var interval = (Clutter.Interval) request.connection.leases.get(
			(int) lid);
		GLib.Value final_v = interval.get_final_value();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("d", final_v.get_double()),
		});
	}
}

static void boot_rpc()
{
	clutter_env();
	OLLMrpc.rpc_register(true);
	GnomeShellRpc.Rpc.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new GnomeShellRpc.Rpc.Daemon());
	Gate.rpc_register();
	try {
		OLLMrpc.Gi.register("Clutter", "16");
	} catch (GLib.Error e) {
		stderr.printf(
			"FAIL clutter-interval-gvalue-gate: Gi.register Clutter: %s\n",
			e.message);
		Process.exit(2);
	}
}

static int run_server(string sock)
{
	boot_rpc();
	var listen = new GnomeShellRpc.Rpc.Listen(sock) {
		live_handles = true,
	};
	if (!listen.start()) {
		stderr.printf(
			"FAIL clutter-interval-gvalue-gate server: listen %s\n", sock);
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

	clutter_env();
	var sock = "/tmp/gsr-clutter-gvalue-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.STDERR_PIPE
		);
	} catch (Error e) {
		stderr.printf(
			"FAIL clutter-interval-gvalue-gate: spawn %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf(
			"FAIL clutter-interval-gvalue-gate: socket missing\n");
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
		args = OLLMrpc.args("is", 1, "clutter-interval-gvalue-gate"),
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
		stderr.printf(
			"FAIL clutter-interval-gvalue-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	try {
		var made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make_interval",
		});
		uint64 lid = made.retval.holds(typeof(uint64))
			? made.retval.get_uint64()
			: (uint64) made.retval.get_int64();
		if (lid == 0) {
			stderr.printf("FAIL clutter-interval-gvalue-gate: lid 0\n");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 2;
		}

		var final_v = GLib.Value(typeof(double));
		final_v.set_double(2.5);
		client.call_poll(new OLLMrpc.Request() {
			method = "Clutter-Interval.set_final",
			lease_id = lid,
			args = OLLMrpc.args("V", final_v),
		});

		var peeked = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.peek_final",
			args = OLLMrpc.args("t", lid),
		});
		double got = peeked.retval.holds(typeof(double))
			? peeked.retval.get_double()
			: peeked.retval.get_float();
		if (Math.fabs(got - 2.5) > 1e-9) {
			stderr.printf(
				"FAIL clutter-interval-gvalue-gate: final=%g want 2.5\n",
				got);
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 1;
		}
	} catch (Error e) {
		stderr.printf(
			"FAIL clutter-interval-gvalue-gate: %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	server.force_exit();
	FileUtils.unlink(sock);
	stderr.printf(
		"PASS clutter-interval-gvalue-gate: set_final GValue IN\n");
	stderr.flush();
	return 0;
}
