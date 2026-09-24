/**
 * Gate: Gi get_property with omitted GValue slot must not GLib-CRITICAL.
 *
 * Live nest still hits type-id-0 CRITICAL on Meta-*.get_property (omit
 * fill-slot). Root: Gi pins {@code GLib.Value(Type.INVALID)} →
 * {@code g_value_init(0)}. Brace-init {@code GLib.Value v = {}} does not.
 *
 * CRITICAL is emitted on the **server** (Gi dispatch); this gate captures
 * server stderr.
 *
 * No OPC edits from this tree.
 *
 *   meson compile -C build gvalue-omit-gate
 *   timeout 5 ./build/tests/call-sync-repro/gvalue-omit-gate
 *
 * PASS → chase consumer.
 * FAIL → file OPC (out GValue init for get_property).
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

	/**
	 * Export a leased {@link GLib.SimpleAction}; reply with its lease id
	 * so the client can call stock get_property without a Live.Interface proxy.
	 */
	public void make_action(OLLMrpc.Request request)
	{
		var action = new GLib.SimpleAction("gate-test", null);
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
		stderr.printf("FAIL gvalue-omit-gate: Gi.register Gio: %s\n", e.message);
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
		stderr.printf("FAIL gvalue-omit-gate server: listen %s\n", sock);
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

static uint count_type0_critical(string blob)
{
	uint n = 0;
	foreach (var line in blob.split("\n")) {
		if (!line.contains("GLib-GObject-CRITICAL")
				&& !line.contains("G_LOG_LEVEL_CRITICAL")) {
			continue;
		}
		if (line.contains("type id '0'")
				|| line.contains("type '(null)'")
				|| line.contains("not currently referenced")) {
			n++;
		}
	}
	return n;
}

int main(string[] args)
{
	if (args.length >= 3 && args[1] == "server") {
		return run_server(args[2]);
	}

	var sock = "/tmp/gsr-gvalue-omit-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.STDERR_PIPE
		);
	} catch (Error e) {
		stderr.printf("FAIL gvalue-omit-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL gvalue-omit-gate: server socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "gvalue-omit-gate"),
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
		stderr.printf("FAIL gvalue-omit-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	try {
		var made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make_action",
		});
		if (!made.retval.holds(typeof(uint64)) && !made.retval.holds(typeof(int64))) {
			stderr.printf(
				"FAIL gvalue-omit-gate: expected lease id, got %s\n",
				made.retval.type().name() ?? "(null)");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 2;
		}
		uint64 lid = made.retval.holds(typeof(uint64))
			? made.retval.get_uint64()
			: (uint64) made.retval.get_int64();
		if (lid == 0) {
			stderr.printf("FAIL gvalue-omit-gate: lease id 0\n");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 2;
		}
		var got = client.call_poll(new OLLMrpc.Request() {
			method = "Gio-SimpleAction.get_property",
			lease_id = lid,
			args = OLLMrpc.args("s", "enabled"),
		});
		stderr.printf(
			"gate: get_property enabled type=%s\n",
			got.retval.type().name() ?? "(null)");
		stderr.flush();
	} catch (Error e) {
		stderr.printf("FAIL gvalue-omit-gate: call: %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	/* Drain server stderr after the omit-slot invoke. */
	Thread.usleep(100 * 1000);
	server.force_exit();
	string server_err = "";
	try {
		var bytes = server.get_stderr_pipe().read_bytes(1 << 20, null);
		server_err = (string) bytes.get_data();
	} catch (Error e) {
		stderr.printf("FAIL gvalue-omit-gate: read server stderr: %s\n", e.message);
		stderr.flush();
		FileUtils.unlink(sock);
		return 2;
	}
	FileUtils.unlink(sock);

	var critical_n = count_type0_critical(server_err);
	if (critical_n > 0) {
		stderr.printf("%s", server_err);
		stderr.printf(
			"FAIL gvalue-omit-gate: %u GObject CRITICAL(s) from Gi omit slot\n",
			critical_n);
		stderr.flush();
		return 1;
	}
	stderr.printf(
		"PASS gvalue-omit-gate: get_property omit, no type-id-0 CRITICAL\n");
	stderr.flush();
	return 0;
}
