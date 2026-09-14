/**
 * Gate: Ffi Helper {@code string[]} — pack / wire / {@code as} vs {@code S}.
 *
 * Boot: client {@code argv_len=4} → Helper {@code argv_len=0} on
 * {@code Helper-WaylandClient.spawnv}.
 *
 * Splits three layers (no WaylandClient, no Response-object fallbacks):
 * 1. Local {@code OLLMrpc.args("as", …)} length after pack
 * 2. Server {@code request.args[0]} length (wire unpack)
 * 3. Vala {@code string[]} param length under signature {@code as} vs {@code S}
 *
 *   meson compile -C build ffi-as-string-array-gate
 *   timeout 5 ./build/tests/call-sync-repro/ffi-as-string-array-gate
 *
 * Expect: {@code echo_S} PASS (OPC Ffi length fix); {@code echo_as}
 * stays empty — pointer-only; Helpers must use {@code S}.
 *
 * No OPC edits from this tree. No response-object fallbacks.
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

	/**
	 * Signature {@code as} — pointer only at FFI.
	 */
	public void echo_as(OLLMrpc.Request request, string[] items)
	{
		string[] wire = items ?? new string[0];
		int req_len = -1;
		if (request.args.size >= 1) {
			req_len = value_as_len(request.args.get(0));
		}
		stderr.printf(
			"server echo_as ffi_len=%d req_args_len=%d args_size=%d\n",
			wire.length, req_len, request.args.size
		);
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("ii", wire.length, req_len),
		});
	}

	/**
	 * Signature {@code S} — pointer + Vala array length at FFI.
	 */
	public void echo_S(OLLMrpc.Request request, string[] items)
	{
		string[] wire = items ?? new string[0];
		int req_len = -1;
		if (request.args.size >= 1) {
			req_len = value_as_len(request.args.get(0));
		}
		stderr.printf(
			"server echo_S ffi_len=%d req_args_len=%d args_size=%d\n",
			wire.length, req_len, request.args.size
		);
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("ii", wire.length, req_len),
		});
	}

	/**
	 * Same Ffi shape as {@code Helper-ThemeContext.set_theme} ({@code sssS}).
	 */
	public void echo_sssS(
		OLLMrpc.Request request,
		string a,
		string b,
		string c,
		string[] items
	) {
		string[] wire = items ?? new string[0];
		stderr.printf(
			"server echo_sssS a='%s' b='%s' c='%s' ffi_len=%d\n",
			a ?? "", b ?? "", c ?? "", wire.length
		);
		stderr.flush();
		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args(
				"iiii",
				(a ?? "").length,
				(b ?? "").length,
				(c ?? "").length,
				wire.length
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

static void call_echo(
	OLLMrpc.Client client,
	string method,
	string[] payload,
	out int ffi_len,
	out int req_len
) throws GLib.Error {
	var response = client.call_poll(new OLLMrpc.Request() {
		method = method,
		args = OLLMrpc.args("as", payload),
	});
	ffi_len = response.args.get(0).get_int();
	req_len = response.args.get(1).get_int();
}

int main(string[] args)
{
	if (args.length >= 3 && args[1] == "server") {
		return run_server(args[2]);
	}

	string[] payload = {"ding", "--arg", "one", "two"};
	var packed = OLLMrpc.args("as", payload);
	int packed_len = -1;
	if (packed.size >= 1) {
		var pv = packed.get(0);
		stderr.printf(
			"client pack type=%s\n",
			pv != null ? (pv.type().name() ?? "?") : "(null)"
		);
		if (pv != null && pv.type() == typeof(string[])) {
			packed_len = ((string[]) pv).length;
		}
	}
	stderr.printf(
		"client payload len=%d packed args len=%d\n",
		payload.length, packed_len
	);
	stderr.flush();
	if (packed_len != payload.length) {
		stderr.printf(
			"FAIL ffi-as-string-array-gate: OLLMrpc.args(\"as\") lost length "
			+ "(packed=%d want=%d) — before wire/Ffi\n",
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
	try {
		call_echo(client, "Gate.echo_as", payload, out as_ffi, out as_req);
		call_echo(client, "Gate.echo_S", payload, out S_ffi, out S_req);
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
		"echo_as ffi=%d req=%d | echo_S ffi=%d req=%d | want=%d\n",
		as_ffi, as_req, S_ffi, S_req, payload.length
	);
	stderr.printf(
		"echo_sssS lens=%d,%d,%d arr=%d want_arr=%d\n",
		s0, s1, s2, s_arr, payload.length
	);
	stderr.flush();

	if (as_req != payload.length && S_req != payload.length) {
		stderr.printf(
			"FAIL ffi-as-string-array-gate: wire/request.args string[] empty "
			+ "(as_req=%d S_req=%d want=%d) — StreamValue or GValue boxed length\n",
			as_req, S_req, payload.length
		);
		stderr.flush();
		return 1;
	}
	if (S_ffi != payload.length) {
		stderr.printf(
			"FAIL ffi-as-string-array-gate: echo_S ffi_len=%d want %d "
			+ "(req_args_len=%d)\n",
			S_ffi, payload.length, S_req
		);
		stderr.flush();
		return 1;
	}
	/* "as" is pointer-only — Vala length-bearing string[] stays empty. */
	if (as_ffi == payload.length) {
		stderr.printf(
			"WARN ffi-as-string-array-gate: echo_as unexpectedly ok "
			+ "(ffi=%d) — contract may have changed\n",
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
			|| s_arr != payload.length) {
		stderr.printf(
			"FAIL ffi-as-string-array-gate: echo_sssS (ThemeContext shape) "
			+ "lens=%d,%d,%d arr=%d\n",
			s0, s1, s2, s_arr
		);
		stderr.flush();
		return 1;
	}
	stderr.printf("PASS ffi-as-string-array-gate\n");
	stderr.flush();
	return 0;
}
