/**
 * Gate: two Requests already on the socket when the server
 * {@code on_input_ready} runs once.
 *
 * Nested 09:23 (app-search start): client wrote
 * {@code Clutter-GestureAction.new} id=750, then from a
 * {@code before-update} Notification {@code Meta.prefs_get_dynamic_workspaces}
 * id=751; mutter {@code recv} 750 only; pending=1 until SIGKILL.
 *
 * Shape: {@code schedule} replies, sleeps (client writes {@code create}),
 * writes {@code before-update} (client nested-writes {@code inner}), sleeps
 * again, returns. One watch wakeup. OPC {@code on_input_ready} loops on the
 * unbuffered IOChannel, not {@code bin.in_stream.get_available()}, so the
 * second Request can sit in the stream buffer forever.
 *
 *   ninja -C build tests/call-sync-repro/coalesced-nested-request-gate
 *   timeout 8 ./build/tests/call-sync-repro/coalesced-nested-request-gate
 */

class Gate : GLib.Object
{
	public static OLLMrpc.Transport.Connection? conn;
	public static int create_n = 0;
	public static int inner_n = 0;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"schedule", "",
			"create", "",
			"inner", "",
			null
		);
		OLLMrpc.Request.register("Gate", new Gate());
	}

	public void schedule(OLLMrpc.Request request)
	{
		Gate.conn = request.connection;
		request.reply(new OLLMrpc.Response() {
			id = request.id,
		});
		Thread.usleep(100000);
		var conn = Gate.conn;
		if (conn == null || conn.bin == null) {
			stderr.printf("server: schedule no connection/bin\n");
			stderr.flush();
			return;
		}
		try {
			conn.bin.write(new OLLMrpc.Notification() {
				method = "before-update",
				object_type = "Gate",
				id = 0,
				message = "09:23-shape",
			});
			conn.bin.out_stream.flush();
		} catch (Error e) {
			stderr.printf("server: schedule notif ERR %s\n", e.message);
			stderr.flush();
			return;
		}
		stderr.printf("server: schedule wrote before-update\n");
		stderr.flush();
		Thread.usleep(100000);
	}

	public void create(OLLMrpc.Request request)
	{
		Gate.create_n++;
		stderr.printf("server: create n=%d\n", Gate.create_n);
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
		stderr.printf("FAIL coalesced-nested-request-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-coalesced-nested-request-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL coalesced-nested-request-gate: spawn %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL coalesced-nested-request-gate: no socket\n");
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
		args = OLLMrpc.args("is", 1, "coalesced-nested-request-gate"),
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
		stderr.printf("FAIL coalesced-nested-request-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	string schedule_err = "";
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.schedule",
		});
	} catch (Error e) {
		schedule_err = e.message;
		stderr.printf("client: schedule ERR %s\n", e.message);
		stderr.flush();
	}

	string create_err = "";
	try {
		client.call_poll(new OLLMrpc.Request() {
			method = "Gate.create",
		});
	} catch (Error e) {
		create_err = e.message;
		stderr.printf("client: create ERR %s\n", e.message);
		stderr.flush();
	}

	server.force_exit();
	FileUtils.unlink(sock);

	if (schedule_err != "") {
		stderr.printf("FAIL coalesced-nested-request-gate: schedule %s\n", schedule_err);
		stderr.flush();
		return 1;
	}
	if (create_err != "") {
		stderr.printf("FAIL coalesced-nested-request-gate: create %s\n", create_err);
		stderr.flush();
		return 1;
	}
	if (!inner_ok) {
		stderr.printf(
			"FAIL coalesced-nested-request-gate: inner from before-update %s (notif_n=%d server_create=%d server_inner=%d)\n"
			+ "  shape: schedule replies+sleeps; create in flight; Notification; nested inner; both Requests in one read.\n"
			+ "  nested 09:23: GestureAction.new recv, prefs_get_dynamic_workspaces never recv.\n",
			inner_err == "" ? "never ran" : inner_err,
			notif_n,
			Gate.create_n,
			Gate.inner_n);
		stderr.flush();
		return 1;
	}
	stderr.printf(
		"PASS coalesced-nested-request-gate: nested inner after delayed notif (notif_n=%d)\n",
		notif_n);
	stderr.flush();
	return 0;
}
