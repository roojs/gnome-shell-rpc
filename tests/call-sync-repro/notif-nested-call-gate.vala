/**
 * Gate: nested {@code call_poll} from a Notification handler while the
 * outer {@code call_poll} is still in flight.
 *
 * Live 08:28 (app-search nested prove): {@code Clutter-Actor.set_width}
 * id=226 in flight; {@code before-update} Notification; client
 * {@code Clutter-Actor.get_children} id=227; mutter never {@code recv} 227
 * ({@code pending=1} until SIGKILL). Outer 226 did reply.
 *
 * Nested requests are {@link OLLMrpc.Client} {@code pending} + the
 * connection read watch — not {@code emit_wait_poll} inside the handler
 * ({@code emit_wait_poll} is for {@code Live.Hook.emit} waiting a reply).
 *
 *   ninja -C build tests/call-sync-repro/notif-nested-call-gate
 *   timeout 8 ./build/tests/call-sync-repro/notif-nested-call-gate
 *
 * | Run | Result |
 * | 2026-09-21 | reply after Notification, no handler drain: **PASS** (queue + watch) |
 * | 2026-09-21 | {@code Thread.usleep} in outer (blocks the watch): **FAIL** |
 * | 2026-09-21 | {@code emit_wait_poll} in outer: PASS but **wrong** — that is emit wait, not queuing |
 */

class Gate : GLib.Object
{
	public static int inner_n = 0;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"outer", "",
			"inner", "",
			null
		);
		OLLMrpc.Request.register("Gate", new Gate());
	}

	public void outer(OLLMrpc.Request request)
	{
		var conn = request.connection;
		if (conn == null || conn.bin == null) {
			stderr.printf("server: outer no connection/bin\n");
			stderr.flush();
			return;
		}
		try {
			conn.bin.write(new OLLMrpc.Notification() {
				method = "before-update",
				object_type = "Gate",
				id = 0,
				message = "08:28-shape",
			});
			conn.bin.out_stream.flush();
		} catch (Error e) {
			stderr.printf("server: outer notif ERR %s\n", e.message);
			stderr.flush();
			return;
		}
		stderr.printf("server: outer wrote before-update\n");
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
	}

	public void inner(OLLMrpc.Request request)
	{
		Gate.inner_n++;
		stderr.printf("server: inner n=%d\n", Gate.inner_n);
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
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
		stderr.printf("FAIL notif-nested-call-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-notif-nested-call-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL notif-nested-call-gate: spawn %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL notif-nested-call-gate: no socket\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 3,
	};

	var notif_n = 0;
	var inner_ok = false;
	string inner_err = "";
	client.notification.connect((notif) => {
		notif_n++;
		stderr.printf("client: NOTIFICATION #%d method=%s\n", notif_n, notif.method);
		stderr.flush();
		if (notif.method != "before-update") {
			return;
		}
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "Gate.inner",
			});
			inner_ok = true;
			stderr.printf("client: nested Gate.inner returned\n");
			stderr.flush();
		} catch (Error e) {
			inner_err = e.message;
			stderr.printf("client: nested Gate.inner ERR %s\n", e.message);
			stderr.flush();
		}
	});

	var loop = new MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "notif-nested-call-gate"),
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
		stderr.printf("FAIL notif-nested-call-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	string outer_err = "";
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.outer",
		});
	} catch (Error e) {
		outer_err = e.message;
		stderr.printf("client: outer ERR %s\n", e.message);
		stderr.flush();
	}

	server.force_exit();
	FileUtils.unlink(sock);

	if (outer_err != "") {
		stderr.printf("FAIL notif-nested-call-gate: outer %s\n", outer_err);
		stderr.flush();
		return 1;
	}
	if (!inner_ok) {
		stderr.printf(
			"FAIL notif-nested-call-gate: inner from before-update %s (notif_n=%d server_inner=%d)\n"
			+ "  shape: outer call_poll; Notification before-update; nested call_poll(inner).\n"
			+ "  live 08:28: set_width then get_children never recv.\n",
			inner_err == "" ? "never ran" : inner_err,
			notif_n,
			Gate.inner_n);
		stderr.flush();
		return 1;
	}
	stderr.printf(
		"PASS notif-nested-call-gate: nested inner from before-update (notif_n=%d)\n",
		notif_n);
	stderr.flush();
	return 0;
}
