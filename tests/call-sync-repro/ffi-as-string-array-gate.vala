/**
 * Gate: Ffi Helper {@code string[]} — pack / wire / {@code as} vs {@code S}.
 *
 * Nest needed usable argv content under {@code Helper-WaylandClient.spawnv}
 * ({@code osS}), not length alone.
 *
 *   meson compile -C build ffi-as-string-array-gate
 *   timeout 5 ./build/tests/call-sync-repro/ffi-as-string-array-gate
 *
 * PASS: {@code echo_S} ffi_len=4 and argv0 content {@code ding}.
 * No OPC code edits from this tree.
 */

class Gate : GLib.Object
{
	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"echo_as", "as",
			"echo_S", "S",
			"echo_sssS", "sssS",
			null
		);
		OLLMrpc.Request.register("Gate", new Gate());
	}

	static int value_as_len(GLib.Value? v)
	{
		if (v == null || v.type() != typeof(string[])) {
			return -1;
		}
		string[] arr = (string[]) v;
		return arr.length;
	}

	public void echo_as(OLLMrpc.Request request, string[] items)
	{
		/* "as" is pointer-only — do not index items. */
		int ffi_len = items.length;
		int req_len = -1;
		if (request.args.size >= 1) {
			req_len = value_as_len(request.args.get(0));
		}
		stderr.printf(
			"server echo_as ffi_len=%d req_args_len=%d\n",
			ffi_len, req_len
		);
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("ii", ffi_len, req_len),
		});
	}

	/**
	 * {@code S}: Helper-shaped — index Ffi {@code items} like spawnv argv.
	 * Upstream must pin a live GStrv so this does not SEGV / empty.
	 */
	public void echo_S(OLLMrpc.Request request, string[] items)
	{
		string[] wire = items ?? new string[0];
		int req_len = -1;
		if (request.args.size >= 1) {
			req_len = value_as_len(request.args.get(0));
		}
		string a0 = (wire.length > 0 && wire[0] != null) ? wire[0] : "";
		int a0_first = (a0.length > 0) ? (int) a0.get_char() : 0;
		stderr.printf(
			"server echo_S ffi_len=%d req_len=%d argv0='%s' "
			+ "argv0_len=%d first=%d\n",
			wire.length, req_len, a0, a0.length, a0_first
		);
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args(
				"iiii", wire.length, req_len, a0.length, a0_first
			),
		});
	}

	public void echo_sssS(
		OLLMrpc.Request request,
		string a,
		string b,
		string c,
		string[] items
	) {
		string[] wire = items ?? new string[0];
		string a0 = (wire.length > 0 && wire[0] != null) ? wire[0] : "";
		stderr.printf(
			"server echo_sssS a='%s' b='%s' c='%s' ffi_len=%d argv0='%s'\n",
			a ?? "", b ?? "", c ?? "", wire.length, a0
		);
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args(
				"iiiii",
				(a ?? "").length,
				(b ?? "").length,
				(c ?? "").length,
				wire.length,
				a0.length
			),
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
		stderr.printf("FAIL ffi-as-string-array-gate server: listen %s\n", sock);
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

	string[] payload = {"ding", "--arg", "one", "two"};
	int want_a0 = (int) payload[0].get_char();
	var packed = OLLMrpc.args("as", payload);
	int packed_len = -1;
	if (packed.size >= 1) {
		var pv = packed.get(0);
		if (pv != null && pv.type() == typeof(string[])) {
			packed_len = ((string[]) pv).length;
		}
	}
	stderr.printf(
		"client payload len=%d packed args len=%d argv0='%s'\n",
		payload.length, packed_len, payload[0]
	);
	stderr.flush();
	if (packed_len != payload.length) {
		stderr.printf(
			"FAIL ffi-as-string-array-gate: OLLMrpc.args(\"as\") lost length "
			+ "(packed=%d want=%d)\n",
			packed_len, payload.length
		);
		stderr.flush();
		return 1;
	}

	var sock = "/tmp/gsr-ffi-as-string-array-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL ffi-as-string-array-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL ffi-as-string-array-gate: server socket never appeared\n");
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
		args = OLLMrpc.args("is", 1, "ffi-as-string-array-gate"),
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
		stderr.printf("FAIL ffi-as-string-array-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		return 2;
	}

	int as_ffi = -1;
	int as_req = -1;
	int S_ffi = -1;
	int S_req = -1;
	int S_a0 = -1;
	int S_first = -1;
	try {
		var as_r = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.echo_as",
			args = OLLMrpc.args("as", payload),
		});
		as_ffi = as_r.args.get(0).get_int();
		as_req = as_r.args.get(1).get_int();

		var S_r = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.echo_S",
			args = OLLMrpc.args("as", payload),
		});
		S_ffi = S_r.args.get(0).get_int();
		S_req = S_r.args.get(1).get_int();
		S_a0 = S_r.args.get(2).get_int();
		S_first = S_r.args.get(3).get_int();
	} catch (Error e) {
		stderr.printf("FAIL ffi-as-string-array-gate: call %s\n", e.message);
		stderr.flush();
		server.force_exit();
		return 2;
	}

	int s0 = -1;
	int s1 = -1;
	int s2 = -1;
	int s_arr = -1;
	int s_a0 = -1;
	try {
		var sss = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.echo_sssS",
			args = OLLMrpc.args(
				"sssas",
				"app.css",
				"theme.css",
				"default.css",
				payload
			),
		});
		s0 = sss.args.get(0).get_int();
		s1 = sss.args.get(1).get_int();
		s2 = sss.args.get(2).get_int();
		s_arr = sss.args.get(3).get_int();
		s_a0 = sss.args.get(4).get_int();
	} catch (Error e) {
		stderr.printf(
			"FAIL ffi-as-string-array-gate: echo_sssS %s\n", e.message
		);
		stderr.flush();
		server.force_exit();
		return 2;
	}

	server.force_exit();
	FileUtils.unlink(sock);

	stderr.printf(
		"echo_as ffi=%d req=%d | echo_S ffi=%d req=%d a0_len=%d first=%d "
		+ "| want=%d want_first=%d\n",
		as_ffi, as_req, S_ffi, S_req, S_a0, S_first,
		payload.length, want_a0
	);
	stderr.printf(
		"echo_sssS lens=%d,%d,%d arr=%d a0_len=%d\n",
		s0, s1, s2, s_arr, s_a0
	);
	stderr.flush();

	if (as_req != payload.length && S_req != payload.length) {
		stderr.printf(
			"FAIL ffi-as-string-array-gate: wire string[] empty "
			+ "(as_req=%d S_req=%d want=%d)\n",
			as_req, S_req, payload.length
		);
		stderr.flush();
		return 1;
	}
	if (S_ffi != payload.length) {
		stderr.printf(
			"FAIL ffi-as-string-array-gate: echo_S ffi_len=%d want %d\n",
			S_ffi, payload.length
		);
		stderr.flush();
		return 1;
	}
	if (S_a0 != payload[0].length || S_first != want_a0) {
		stderr.printf(
			"FAIL ffi-as-string-array-gate: echo_S argv0 empty/wrong "
			+ "(a0_len=%d first=%d want_len=%d want_first=%d) — "
			+ "OPC Ffi \"S\" must pin usable GStrv content\n",
			S_a0, S_first, payload[0].length, want_a0
		);
		stderr.flush();
		return 1;
	}
	if (as_ffi == payload.length) {
		stderr.printf(
			"WARN ffi-as-string-array-gate: echo_as unexpectedly ok (ffi=%d)\n",
			as_ffi
		);
		stderr.flush();
	} else {
		stderr.printf(
			"ok: echo_as ffi_len=%d (pointer-only; Helpers use S)\n",
			as_ffi
		);
		stderr.flush();
	}
	if (s0 != "app.css".length
			|| s1 != "theme.css".length
			|| s2 != "default.css".length
			|| s_arr != payload.length
			|| s_a0 != payload[0].length) {
		stderr.printf(
			"FAIL ffi-as-string-array-gate: echo_sssS "
			+ "lens=%d,%d,%d arr=%d a0=%d\n",
			s0, s1, s2, s_arr, s_a0
		);
		stderr.flush();
		return 1;
	}
	stderr.printf("PASS ffi-as-string-array-gate\n");
	stderr.flush();
	return 0;
}
