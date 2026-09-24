/**
 * Gate: live handle decode must reuse Client.proxies (object identity).
 *
 * Shape: server exports peer → client decodes same lid twice → pointers
 * must be equal. Today parse_object remints every time.
 *
 * No OPC edits from this tree.
 *
 *   meson compile -C build proxy-reuse-gate
 *   timeout 5 ./build/tests/call-sync-repro/proxy-reuse-gate
 *
 * FAIL → OPC parse_object must reuse proxies.
 * PASS → create-time still needs Runtime.register_handle into proxies.
 */

class Peer : GLib.Object, OLLMrpc.Live.Interface
{
	public uint64 rpc_lid { get; set construct; default = 0; }
}

class Gate : GLib.Object
{
	public Peer? peer;

	public static void rpc_register()
	{
		OLLMrpc.Bin.register("Gate-Peer", typeof(Peer));
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"make", "",
			"get_peer", "",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	public void make(OLLMrpc.Request request)
	{
		this.peer = new Peer();
		request.connection.export(this.peer);
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("o", this.peer),
		});
	}

	public void get_peer(OLLMrpc.Request request)
	{
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			retval = OLLMrpc.val("o", this.peer),
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
		stderr.printf("FAIL proxy-reuse-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-proxy-reuse-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL proxy-reuse-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL proxy-reuse-gate: server socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "proxy-reuse-gate"),
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
		stderr.printf("FAIL proxy-reuse-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	try {
		var made = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.make",
		});
		var a = made.retval.get_object();
		if (a == null) {
			stderr.printf("FAIL proxy-reuse-gate: make returned null\n");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 2;
		}
		var again = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.get_peer",
		});
		var b = again.retval.get_object();
		if (b == null) {
			stderr.printf("FAIL proxy-reuse-gate: get_peer returned null\n");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 2;
		}
		if (a != b) {
			stderr.printf(
				"FAIL proxy-reuse-gate: decode reminted — OPC parse_object must reuse proxies\n");
			stderr.flush();
			server.force_exit();
			FileUtils.unlink(sock);
			return 1;
		}
		stderr.printf("PASS proxy-reuse-gate: same object\n");
		stderr.flush();
	} catch (Error e) {
		stderr.printf("FAIL proxy-reuse-gate: %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	server.force_exit();
	FileUtils.unlink(sock);
	return 0;
}
