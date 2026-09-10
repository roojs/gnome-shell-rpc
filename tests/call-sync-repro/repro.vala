/**
 * call_sync × Live.Invoke — pure-gio hang harness.
 *
 * Live now (after OPC first-unsent send):
 *   remove_child → Invoke → nested reply SENT + server recv
 *   → no Response for reply or remove_child → dead.
 *
 * Cause to model: Hook.emit spins the *same* MainContext that owns
 * Connection.on_input_ready. While still inside dispatch(remove_child),
 * a non-reentrant read watch cannot dispatch the reply → emit waits
 * forever. (Harness previously cheated with a side-thread drain.)
 *
 *   meson compile -C build
 *   BIN=./build/tests/call-sync-repro/call-sync-repro
 *   timeout 3 $BIN idle        # FAIL — Idle(default) reply
 *   timeout 3 $BIN opc-head    # FAIL — head-only send
 *   timeout 3 $BIN stack       # FAIL — emit inside on_input (live)
 *   timeout 3 $BIN reenter     # PASS — nested dispatch during emit
 *   timeout 3 $BIN child       # PASS — child GI + reenter
 */

delegate void Work();

private enum MsgKind {
	REQUEST,
	RESPONSE,
	INVOKE,
}

private class Msg
{
	public MsgKind kind;
	public int id;
	public string method;
	public Hook? hook;
}

private class Hook
{
	public bool replied;
	public int reply_value;
}

private class Pending
{
	public int id;
	public string method;
	public bool sent;
	public Msg? out_msg;
}

private class Client
{
	public static string mode = "idle";
	public static bool send_head_only = false;
	/** Allow on_input to dispatch while already in dispatch (Constraint). */
	public static bool server_reenter = true;
	public static MainLoop? sync_loop;
	public static int sync_depth;
	public static int next_id = 1;
	public static int waiting_id;
	public static HashTable<int, int>? ready;
	public static GLib.Queue<Pending>? pending;
	public static GLib.Queue<Msg>? to_client;
	public static GLib.Queue<Msg>? to_server;
	public static Mutex wire_lock = Mutex();
	public static MainContext? server_ctx;

	public static void ensure()
	{
		if (Client.ready == null) {
			Client.ready = new HashTable<int, int>(direct_hash, direct_equal);
		}
		if (Client.pending == null) {
			Client.pending = new GLib.Queue<Pending>();
		}
		if (Client.to_client == null) {
			Client.to_client = new GLib.Queue<Msg>();
		}
		if (Client.to_server == null) {
			Client.to_server = new GLib.Queue<Msg>();
		}
	}

	public static void wake_sync()
	{
		if (Client.sync_loop != null) {
			Client.sync_loop.get_context().wakeup();
			Client.sync_loop.quit();
		}
	}

	public static void wake_server()
	{
		if (Client.server_ctx != null) {
			Client.server_ctx.wakeup();
		}
	}

	public static void push_to_client(Msg m)
	{
		Client.ensure();
		Client.wire_lock.lock();
		Client.to_client.push_tail(m);
		Client.wire_lock.unlock();
		Client.wake_sync();
	}

	public static void push_to_server(Msg m)
	{
		Client.ensure();
		Client.wire_lock.lock();
		Client.to_server.push_tail(m);
		Client.wire_lock.unlock();
		Client.wake_server();
	}

	public static void flush_unsent()
	{
		Client.ensure();
		if (Client.pending.is_empty()) {
			return;
		}
		Pending? to_send = null;
		if (Client.send_head_only) {
			var head = Client.pending.peek_head();
			if (head != null && !head.sent) {
				to_send = head;
			}
		} else {
			unowned GLib.List<Pending> node = Client.pending.head;
			while (node != null) {
				if (!node.data.sent) {
					to_send = node.data;
					break;
				}
				node = node.next;
			}
		}
		if (to_send == null || to_send.out_msg == null) {
			return;
		}
		stderr.printf("  >> send id=%d %s%s\n",
			to_send.id, to_send.method,
			Client.send_head_only ? " (head-only)" : "");
		to_send.sent = true;
		Client.push_to_server(to_send.out_msg);
	}

	public static void complete_pending(int id)
	{
		Client.ensure();
		Pending? found = null;
		unowned GLib.List<Pending> node = Client.pending.head;
		while (node != null) {
			if (node.data.id == id) {
				found = node.data;
				break;
			}
			node = node.next;
		}
		if (found != null) {
			Client.pending.remove(found);
		}
		Client.ready.insert(id, 1);
		Client.wake_sync();
	}

	public static bool on_read()
	{
		Client.ensure();
		Msg? m = null;
		Client.wire_lock.lock();
		if (!Client.to_client.is_empty()) {
			m = Client.to_client.pop_head();
		}
		Client.wire_lock.unlock();
		if (m == null) {
			return Source.CONTINUE;
		}
		switch (m.kind) {
		case MsgKind.RESPONSE:
			stderr.printf("  << Response id=%d\n", m.id);
			Client.complete_pending(m.id);
			break;
		case MsgKind.INVOKE:
			stderr.printf("  << Invoke\n");
			try {
				Client.handle_invoke(m.hook);
			} catch (Error e) {
				stderr.printf("  INVERR: %s\n", e.message);
			}
			break;
		default:
			break;
		}
		return Source.CONTINUE;
	}

	public static void handle_invoke(Hook hook) throws Error
	{
		switch (Client.mode) {
		case "idle":
			stderr.printf("  fix=idle → Idle(default)\n");
			Idle.add(() => {
				stderr.printf("  Idle(default) fired\n");
				hook.reply_value = 99;
				hook.replied = true;
				Client.wake_server();
				return Source.REMOVE;
			});
			break;

		case "opc-head":
		case "stack":
		case "reenter":
			stderr.printf("  fix=%s → nested call_sync reply\n", Client.mode);
			Client.call_sync_inner("Live.Callback.reply", () => {
				Client.enqueue_request("Live.Callback.reply", hook);
			}, true);
			break;

		case "child":
			stderr.printf("  fix=child → child GI then reply\n");
			Client.call_sync_inner("Clutter-Actor.child", () => {
				Client.enqueue_request("Clutter-Actor.child", null);
			}, true);
			Client.call_sync_inner("Live.Callback.reply", () => {
				Client.enqueue_request("Live.Callback.reply", hook);
			}, true);
			break;

		default:
			throw new IOError.FAILED("unknown mode %s", Client.mode);
		}
	}

	public static void enqueue_request(string method, Hook? hook)
	{
		Client.ensure();
		var id = Client.waiting_id;
		var p = new Pending();
		p.id = id;
		p.method = method;
		p.sent = false;
		p.out_msg = new Msg() {
			kind = MsgKind.REQUEST,
			id = id,
			method = method,
			hook = hook,
		};
		Client.pending.push_tail(p);
		stderr.printf("  enqueue id=%d %s (pending=%u)\n",
			id, method, Client.pending.length);
	}

	public static int call_sync(string name, owned Work send) throws Error
	{
		return Client.call_sync_inner(name, (owned) send, true);
	}

	public static int call_sync_inner(
		string name, owned Work send, bool allow_reenter
	) throws Error {
		Client.ensure();
		if (Client.sync_depth > 0 && !allow_reenter) {
			throw new IOError.FAILED(
				"nested call_sync is not supported (%s)", name);
		}

		var outer = (Client.sync_loop == null);
		if (outer) {
			Client.sync_loop = new MainLoop(new MainContext(), false);
		}

		var my_id = Client.next_id++;
		var saved_waiting = Client.waiting_id;
		Client.waiting_id = my_id;
		Client.sync_depth++;
		stderr.printf("call_sync BEGIN %s id=%d depth=%d\n",
			name, my_id, Client.sync_depth);

		int? result = null;
		try {
			send();
			var deadline = get_monotonic_time() + 2 * TimeSpan.SECOND;
			while (result == null && get_monotonic_time() < deadline) {
				if (Client.ready.contains(my_id)) {
					result = Client.ready.get(my_id);
					Client.ready.remove(my_id);
					break;
				}
				Client.flush_unsent();
				if (Client.ready.contains(my_id)) {
					result = Client.ready.get(my_id);
					Client.ready.remove(my_id);
					break;
				}
				var drain = new IdleSource();
				drain.set_callback(() => {
					Client.wire_lock.lock();
					var empty = Client.to_client.is_empty();
					Client.wire_lock.unlock();
					if (!empty) {
						Client.on_read();
					}
					Client.flush_unsent();
					if (Client.sync_loop != null) {
						Client.sync_loop.quit();
					}
					return Source.REMOVE;
				});
				drain.attach(Client.sync_loop.get_context());
				var to = new TimeoutSource(20);
				to.set_callback(() => {
					if (Client.sync_loop != null) {
						Client.sync_loop.quit();
					}
					return Source.REMOVE;
				});
				to.attach(Client.sync_loop.get_context());
				Client.sync_loop.run();
				to.destroy();
			}
			if (result == null) {
				throw new IOError.TIMED_OUT("%s id=%d: no Response", name, my_id);
			}
			stderr.printf("call_sync END %s id=%d → %d\n", name, my_id, result);
			return result;
		} finally {
			Client.sync_depth--;
			Client.waiting_id = saved_waiting;
			if (outer) {
				Client.sync_loop = null;
			}
		}
	}
}

/**
 * Server shaped like OPC Connection.on_input_ready + Hook.emit:
 * same MainContext for the read watch and emit's iteration.
 */
private class Server
{
	public Hook hook = new Hook();
	public MainContext ctx = new MainContext();
	public MainLoop loop;
	public int dispatch_depth = 0;
	public GLib.Queue<Msg> deferred = new GLib.Queue<Msg>();

	public Server()
	{
		this.loop = new MainLoop(this.ctx, false);
		Client.server_ctx = this.ctx;
	}

	public void start()
	{
		/*
		 * Read watch on the emit context — like Connection IO source.
		 * Non-reenter (stack): while dispatch_depth > 0, only queue;
		 * log recv so the live "recv reply then dead" shape shows up.
		 * Reenter: nested on_input dispatches (Constraint-shaped).
		 */
		var src = new TimeoutSource(2);
		src.set_callback(() => {
			this.on_input();
			return Source.CONTINUE;
		});
		src.attach(this.ctx);
		new Thread<void*>("server", () => {
			this.loop.run();
			return null;
		});
	}

	public void stop()
	{
		this.loop.quit();
		this.ctx.wakeup();
	}

	/** Connection.on_input_ready analogue. */
	private void on_input()
	{
		Client.ensure();
		while (true) {
			Msg? m = null;
			Client.wire_lock.lock();
			if (!Client.to_server.is_empty()) {
				m = Client.to_server.pop_head();
			}
			Client.wire_lock.unlock();
			if (m == null) {
				return;
			}
			stderr.printf("server: recv id=%d %s (depth=%d)\n",
				m.id, m.method, this.dispatch_depth);
			if (this.dispatch_depth > 0 && !Client.server_reenter) {
				/*
				 * Live hang: still inside dispatch(remove_child) / emit.
				 * Message is off the wire (recv logged) but not handled.
				 */
				stderr.printf(
					"server: DEFER id=%d (in on_input dispatch, no reenter)\n",
					m.id);
				this.deferred.push_tail(m);
				continue;
			}
			this.dispatch_one(m);
		}
	}

	private void dispatch_one(Msg m)
	{
		this.dispatch_depth++;
		try {
			this.handle_request(m);
		} finally {
			this.dispatch_depth--;
		}
		if (this.dispatch_depth == 0) {
			while (!this.deferred.is_empty()) {
				var d = this.deferred.pop_head();
				stderr.printf("server: drain deferred id=%d %s\n",
					d.id, d.method);
				this.dispatch_one(d);
			}
		}
	}

	private void handle_request(Msg m)
	{
		stderr.printf("server: dispatch id=%d %s\n", m.id, m.method);
		switch (m.method) {
		case "Work.do":
			this.emit_hook();
			if (!this.hook.replied) {
				stderr.printf("server: Work.do aborted (emit hung)\n");
				return;
			}
			Client.push_to_client(new Msg() {
				kind = MsgKind.RESPONSE,
				id = m.id,
				method = m.method,
			});
			break;

		case "Clutter-Actor.child":
			stderr.printf("server: child ok id=%d\n", m.id);
			Client.push_to_client(new Msg() {
				kind = MsgKind.RESPONSE,
				id = m.id,
				method = m.method,
			});
			break;

		case "Live.Callback.reply":
			stderr.printf("server: reply → hook done id=%d\n", m.id);
			var h = m.hook ?? this.hook;
			h.replied = true;
			h.reply_value = 99;
			Client.push_to_client(new Msg() {
				kind = MsgKind.RESPONSE,
				id = m.id,
				method = m.method,
			});
			this.ctx.wakeup();
			break;

		default:
			stderr.printf("server: unknown %s\n", m.method);
			break;
		}
	}

	/**
	 * Hook.emit — spin the *same* context as on_input (default.iteration).
	 * Poll on_input each turn: live IO watch may deliver bytes during
	 * iteration; non-reenter defers dispatch while depth &gt; 0.
	 */
	private void emit_hook()
	{
		stderr.printf("server: Hook.emit BEGIN\n");
		this.hook.replied = false;
		Client.push_to_client(new Msg() {
			kind = MsgKind.INVOKE,
			id = 0,
			method = "Live.Invoke",
			hook = this.hook,
		});

		var deadline = get_monotonic_time() + 1500 * TimeSpan.MILLISECOND;
		while (!this.hook.replied && get_monotonic_time() < deadline) {
			this.on_input();
			if (this.hook.replied) {
				break;
			}
			var quit = false;
			var to = new TimeoutSource(5);
			to.set_callback(() => {
				quit = true;
				return Source.REMOVE;
			});
			to.attach(this.ctx);
			while (!quit && !this.hook.replied) {
				this.ctx.iteration(true);
				this.on_input();
			}
			to.destroy();
		}
		if (!this.hook.replied) {
			stderr.printf(
				"server: Hook.emit TIMEOUT deferred=%u\n",
				this.deferred.length);
			return;
		}
		stderr.printf("server: Hook.emit done\n");
	}
}

int main(string[] args)
{
	string[] modes = { "idle", "opc-head", "stack", "reenter", "child" };
	var mode = args.length > 1 ? args[1] : "idle";
	var ok = false;
	foreach (var m in modes) {
		if (mode == m) {
			ok = true;
			break;
		}
	}
	if (!ok) {
		stderr.printf("usage: %s [%s]\n", args[0], string.joinv("|", modes));
		return 2;
	}

	Client.mode = mode;
	Client.send_head_only = (mode == "opc-head");
	Client.server_reenter = (mode != "stack" && mode != "opc-head" && mode != "idle");
	/* idle: parent send ok; fail on Idle reply. stack: first-unsent + no reenter. */
	if (mode == "idle") {
		Client.send_head_only = false;
		Client.server_reenter = true;
	}
	if (mode == "opc-head") {
		Client.server_reenter = true; /* isolate head-only send */
	}
	if (mode == "stack") {
		Client.send_head_only = false;
		Client.server_reenter = false;
	}
	if (mode == "reenter" || mode == "child") {
		Client.send_head_only = false;
		Client.server_reenter = true;
	}

	Client.next_id = 1;
	Client.ready = null;
	Client.pending = null;
	Client.to_client = null;
	Client.to_server = null;
	Client.sync_loop = null;
	Client.sync_depth = 0;
	Client.waiting_id = 0;

	var server = new Server();
	server.start();
	Thread.usleep(20000);

	Error? err = null;
	try {
		Client.call_sync("Work.do", () => {
			Client.enqueue_request("Work.do", null);
		});
	} catch (Error e) {
		err = e;
		stderr.printf("ERR: %s\n", e.message);
	}

	server.stop();

	if (err == null && server.hook.replied && server.hook.reply_value == 99) {
		stderr.printf("PASS %s\n", mode);
		return 0;
	}
	stderr.printf("FAIL %s err=%s replied=%s deferred=%u\n",
		mode,
		err != null ? err.message : "none",
		server.hook.replied.to_string(),
		server.deferred.length);
	return 1;
}
