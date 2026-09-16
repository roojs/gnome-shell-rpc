/**
 * Gate: GValue* IN over Gi — append the held {@link GLib.Value} to
 * Request.args (StreamValue + Gi value_keep). Do NOT memcpy the Value
 * struct as {@code ay}.
 *
 * Proves the call shape Transition.set_to / Interval.set_final_value
 * must use. No Clutter, no gi-stub, no generator.
 *
 * OPC path already FIXED 2026-09-11 (set_property). This gate is the
 * external smoke before undeny + generator packing (bug §2).
 *
 *   meson compile -C build gvalue-in-gate
 *   timeout 5 ./build/tests/call-sync-repro/gvalue-in-gate
 *
 * PASS → generator may pack GObject.Value IN as args.add(value).
 * FAIL → OPC (do not hack Transition overrides).
 */

class Gate : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"make_action", "",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	public void make_action(OLLMrpc.Request request)
	{
		var action = new GLib.SimpleAction.stateful(
			"gate-in",
			null,
			new GLib.Variant.boolean(true)
		);
		var lid = request.connection.export(action);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("t", (uint64) lid),
		});
	}
}

static void boot_rpc()
{
	OLLMrpc.rpc_register(true);
	GnomeShellRpc.Rpc.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new GnomeShellRpc.Rpc.Daemon());
	Gate.rpc_register();
	try {
		OLLMrpc.Gi.register("Gio", "2.0");
	} catch (GLib.Error e) {
		stderr.printf("FAIL gvalue-in-gate: Gi.register Gio: %s\n", e.message);
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
		stderr.printf("FAIL gvalue-in-gate server: listen %s\n", sock);
		stderr.flush();
		return 2;
	}
	stderr.printf("server: listening %s\n", sock);
	stderr.flush();
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

	var sock = "/tmp/gsr-gvalue-in-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.STDERR_PIPE
		);
	} catch (Error e) {
		stderr.printf("FAIL gvalue-in-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL gvalue-in-gate: server socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "gvalue-in-gate"),
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
		stderr.printf("FAIL gvalue-in-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	try {
		var made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make_action",
		});
		uint64 lid = made.retval.holds(typeof(uint64))
			? made.retval.get_uint64()
			: (uint64) made.retval.get_int64();
		if (lid == 0) {
			stderr.printf("FAIL gvalue-in-gate: lease id 0\n");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 2;
		}

		/*
		 * Correct shape: wire row IS the GValue payload (bool), not a
		 * memcpy of the GValue struct. Same for set_to(double) later.
		 */
		client.call_poll(new OLLMrpc.Request() {
			method = "Gio-SimpleAction.set_property",
			lease_id = lid,
			args = OLLMrpc.args("sb", "enabled", false),
		});

		var got = client.call_poll(new OLLMrpc.Request() {
			method = "Gio-SimpleAction.get_property",
			lease_id = lid,
			args = OLLMrpc.args("s", "enabled"),
		});
		if (!got.retval.holds(typeof(bool)) || got.retval.get_boolean()) {
			stderr.printf(
				"FAIL gvalue-in-gate: expected enabled=false, got type=%s\n",
				got.retval.type().name() ?? "(null)");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 1;
		}

		/*
		 * Explicit ArrayList.add(Value) — generator must emit this, not
		 * OLLMrpc.args("ay", bytes_of_GValue_struct).
		 */
		var name_v = GLib.Value(typeof(string));
		name_v.set_string("enabled");
		var bool_v = GLib.Value(typeof(bool));
		bool_v.set_boolean(true);
		var packed = new Gee.ArrayList<GLib.Value?>();
		packed.add(name_v);
		packed.add(bool_v);
		client.call_poll(new OLLMrpc.Request() {
			method = "Gio-SimpleAction.set_property",
			lease_id = lid,
			args = packed,
		});
		got = client.call_poll(new OLLMrpc.Request() {
			method = "Gio-SimpleAction.get_property",
			lease_id = lid,
			args = OLLMrpc.args("s", "enabled"),
		});
		if (!got.retval.holds(typeof(bool)) || !got.retval.get_boolean()) {
			stderr.printf(
				"FAIL gvalue-in-gate: ArrayList Value pack enabled!=true\n");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 1;
		}
	} catch (Error e) {
		stderr.printf("FAIL gvalue-in-gate: call: %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	server.force_exit();
	FileUtils.unlink(sock);
	stderr.printf(
		"PASS gvalue-in-gate: set_property GValue IN (args + ArrayList)\n");
	stderr.flush();
	return 0;
}
