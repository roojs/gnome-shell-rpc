/**
 * Gate: two **nested** {@code Live.Hook.emit} calls on the **same callback id**
 * must each get their own reply.
 *
 * {@link OLLMrpc.Live.Hook} keeps **one** {@code replied} flag and **one**
 * {@code reply_id} per callback row, and {@code emit} loops
 * {@code while (!this.replied)}. So when a hook is emitted re-entrantly, the
 * inner emit resets {@code replied} and overwrites {@code reply_id}; the
 * client's reply to the **inner** Invoke then releases the **outer** emit as
 * well, which returns carrying the inner call's {@code reply_args}. The
 * client's later reply to the outer Invoke finds no row with that
 * {@code reply_id} and comes back INVALID_PARAMS.
 *
 * This is not hypothetical. A single nested session log
 * (`org.gnome.ShellRpc.debug.log`, 2026-09-17 run) has **86** `invoke ENTER`
 * events for a callback id that was already on the client's invoke stack, and
 * reaches an invoke nesting depth of 4. Live that means vfunc relays
 * (`relay_get_preferred_height` and friends) resolve with **another** actor's
 * measurement — which queues more relayout, which emits again: the storm the
 * "hang after settle" freeze sits in
 * (docs/bugs/done/2026-09-18-hang-after-settle-race.md).
 *
 * Shape:
 *   client call_poll(Gate.provoke)   → server emit A (reply_id=RA), blocks
 *   client INVOKE #1 handler → call_poll(Gate.provoke)  [re-entrant, same hook]
 *                            → server emit B (reply_id=RB), blocks
 *   client INVOKE #2 handler → reply RB = 22
 *   server emit B returns 22 — and emit A must NOT return yet
 *   client INVOKE #1 handler → reply RA = 11
 *   server emit A returns 11
 *
 *   meson compile -C build same-hook-reentrant-emit-gate
 *   timeout 20 ./build/tests/call-sync-repro/same-hook-reentrant-emit-gate
 *
 * PASS → nested emit on one hook is safe → the wrong-measurement storm is not
 *        this, keep chasing the consumer corridor.
 * FAIL → OPC: {@link OLLMrpc.Live.Hook} needs per-emit reply state (a stack of
 *        reply_id/replied, or a Hook per emit). File in OLLMchat docs/bugs/;
 *        do not edit OLLMchat from this tree; keep this FAIL gate.
 */

class Gate : GLib.Object
{
	/** Emit nesting on the server (1 = outer, 2 = re-entrant inner). */
	public static int depth = 0;

	public static uint outer_got = 0;
	public static uint inner_got = 0;
	public static bool outer_returned_before_inner = false;
	public static bool inner_done = false;

	public static void rpc_register()
	{
		OLLMrpc.Request.add_class(
			"Gate", typeof(Gate),
			"provoke", "t",
			null
		);
		OLLMrpc.Request.register_live("Gate", new Gate());
	}

	/**
	 * Emit on the caller's hook and report what came back.
	 *
	 * Called twice on the SAME callback id — the second time from inside the
	 * client's handler for the first Invoke, so the second emit nests inside
	 * the first.
	 */
	public void provoke(OLLMrpc.Request request, uint64 callback_id)
	{
		var conn = request.connection;
		var id = (int) callback_id;
		if (conn == null || !conn.callbacks.has_key(id)) {
			stderr.printf("server: provoke no callback row\n");
			stderr.flush();
			conn.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
			return;
		}
		var hook = conn.callbacks.get(id);

		Gate.depth++;
		var my_depth = Gate.depth;
		stderr.printf("server: emit BEGIN depth=%d\n", my_depth);
		stderr.flush();

		hook.emit(OLLMrpc.args("u", (uint) my_depth));

		uint got = 0;
		if (hook.reply_args.size > 0) {
			got = hook.reply_args.get(0).get_uint();
		}
		stderr.printf("server: emit END depth=%d got=%u\n", my_depth, got);
		stderr.flush();

		if (my_depth == 1) {
			Gate.outer_got = got;
			if (!Gate.inner_done) {
				Gate.outer_returned_before_inner = true;
			}
		} else {
			Gate.inner_got = got;
			Gate.inner_done = true;
		}
		Gate.depth--;

		request.reply(new OLLMrpc.Response() {
			id = request.id,
			args = OLLMrpc.args("u", got),
		});
	}
}

static void boot_rpc()
{
	OLLMrpc.rpc_register(true);
	GnomeShellRpc.Rpc.Daemon.rpc_register();
	OLLMrpc.Request.register("RPC-Daemon", new GnomeShellRpc.Rpc.Daemon());
	/* The product server replaces the stock live singleton (Server.vala). */
	GnomeShellRpc.Rpc.LiveCallback.rpc_register();
	Gate.rpc_register();
}

static int run_server(string sock)
{
	boot_rpc();
	var listen = new GnomeShellRpc.Rpc.Listen(sock) {
		live_handles = true,
	};
	if (!listen.start()) {
		stderr.printf("FAIL same-hook-reentrant-emit-gate server: listen %s\n", sock);
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

	var sock = "/tmp/gsr-same-hook-reentrant-emit-gate-%d.sock".printf(
		(int) (get_monotonic_time() & 0x7fffffff));
	FileUtils.unlink(sock);

	Subprocess? server = null;
	try {
		server = new Subprocess.newv(
			{self_exe(args[0]), "server", sock},
			SubprocessFlags.NONE
		);
	} catch (Error e) {
		stderr.printf("FAIL same-hook-reentrant-emit-gate: spawn server %s\n", e.message);
		stderr.flush();
		return 2;
	}

	var wait_deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
	while (!FileUtils.test(sock, FileTest.EXISTS)
			&& get_monotonic_time() < wait_deadline) {
		Thread.usleep(10000);
	}
	if (!FileUtils.test(sock, FileTest.EXISTS)) {
		stderr.printf("FAIL same-hook-reentrant-emit-gate: socket never appeared\n");
		stderr.flush();
		server.force_exit();
		return 2;
	}

	boot_rpc();
	var client = new OLLMrpc.Client("", "", sock) {
		live_handles = true,
		call_timeout_seconds = 5,
	};

	uint64 cb_id = 0;
	var invoke_n = 0;
	string nested_err = "";
	/* The rejected reply comes back with an empty message — track the throw. */
	var outer_reply_failed = false;
	var inner_reply_failed = false;
	string outer_reply_err = "";
	string inner_reply_err = "";

	client.invoke.connect((call) => {
		invoke_n++;
		var n = invoke_n;
		var which = call.args.size > 0 ? call.args.get(0).get_uint() : 0;
		stderr.printf("client: INVOKE #%d id=%d reply_id=%d emit=%u\n",
			n, call.id, call.reply_id, which);
		stderr.flush();

		if (n == 1) {
			/* Re-enter the SAME hook while its first emit is still up. */
			try {
				client.call_poll(new OLLMrpc.Request() {
					method = "Gate.provoke",
					args = OLLMrpc.args("t", cb_id),
				});
			} catch (Error e) {
				nested_err = e.message;
				stderr.printf("client: nested provoke ERR %s\n", e.message);
				stderr.flush();
			}
		}

		/* Distinct value per emit: 11 for the outer, 22 for the inner. */
		var value = (uint) (n * 11);
		try {
			client.call_poll(new OLLMrpc.Request() {
				method = "RPC-Live-Callback.reply",
				args = OLLMrpc.args("tu", (uint64) call.reply_id, value),
			});
			stderr.printf("client: replied #%d value=%u\n", n, value);
			stderr.flush();
		} catch (Error e) {
			if (n == 1) {
				outer_reply_failed = true;
				outer_reply_err = e.message;
			} else {
				inner_reply_failed = true;
				inner_reply_err = e.message;
			}
			stderr.printf("client: reply #%d ERR %s\n", n, e.message);
			stderr.flush();
		}
	});

	var loop = new MainLoop();
	bool connected = false;
	string connect_err = "";
	client.connect.begin(new OLLMrpc.Request() {
		method = "RPC-Daemon.hello",
		args = OLLMrpc.args("is", 1, "same-hook-reentrant-emit-gate"),
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
		stderr.printf("FAIL same-hook-reentrant-emit-gate: connect %s\n", connect_err);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}

	try {
		var reg = client.call_poll(new OLLMrpc.Request() {
			method = "RPC-Live-Callback.register",
		});
		cb_id = reg.args.get(0).get_uint64();
	} catch (Error e) {
		stderr.printf("FAIL same-hook-reentrant-emit-gate: register %s\n", e.message);
		stderr.flush();
		server.force_exit();
		FileUtils.unlink(sock);
		return 2;
	}
	stderr.printf("client: callback id=%llu\n", cb_id);
	stderr.flush();

	uint outer_result = 0;
	string provoke_err = "";
	try {
		var response = client.call_poll(new OLLMrpc.Request() {
			method = "Gate.provoke",
			args = OLLMrpc.args("t", cb_id),
		});
		if (response.args.size > 0) {
			outer_result = response.args.get(0).get_uint();
		}
	} catch (Error e) {
		provoke_err = e.message;
		stderr.printf("client: provoke ERR %s\n", e.message);
		stderr.flush();
	}

	server.force_exit();
	FileUtils.unlink(sock);

	if (provoke_err != "" || nested_err != "") {
		stderr.printf(
			"FAIL same-hook-reentrant-emit-gate: provoke=%s nested=%s\n",
			provoke_err == "" ? "ok" : provoke_err,
			nested_err == "" ? "ok" : nested_err);
		stderr.flush();
		return 1;
	}
	if (outer_result != 11 || outer_reply_failed) {
		stderr.printf(
			"FAIL same-hook-reentrant-emit-gate: outer emit got %u, want 11%s\n"
			+ "  outer reply: %s\n"
			+ "  shape: Live.Hook has ONE replied/reply_id per callback row, so the\n"
			+ "  inner emit's reply released the outer emit too — the outer vfunc\n"
			+ "  relay resolves with the inner call's value, and the real outer\n"
			+ "  reply is rejected (no row with that reply_id).\n"
			+ "  fix (OLLMchat): per-emit reply state on Live.Hook (stack of\n"
			+ "  reply_id/replied), so nested emit on one hook is not aliased.\n",
			outer_result,
			outer_result == 22 ? " (got the INNER emit's value)" : "",
			!outer_reply_failed
				? "ok"
				: "REJECTED \"%s\" (no row with that reply_id)".printf(
					outer_reply_err));
		stderr.flush();
		return 1;
	}
	if (inner_reply_failed) {
		stderr.printf("FAIL same-hook-reentrant-emit-gate: inner reply rejected \"%s\"\n",
			inner_reply_err);
		stderr.flush();
		return 1;
	}
	stderr.printf(
		"PASS same-hook-reentrant-emit-gate: outer=%u inner=%u (invokes=%d)\n",
		outer_result, Gate.inner_got, invoke_n);
	stderr.flush();
	return 0;
}
