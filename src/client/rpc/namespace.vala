namespace Gsr.Client.Rpc
{
	[CCode (cname = "gsr_client_clutter_batch_flush_prop")]
	private extern void flush_prop(GLib.Object? instance) throws GLib.Error;

	/**
	 * Sync RPC call with positional {@link GLib.Value}s and optional instance.
	 *
	 * An open {@link Clutter.Actor.prop_batch} with nothing in it is
	 * closed. A non-empty map is sent as
	 * ''Gsr-Clutter-Actor.add_properties'' and closed. Entries are added
	 * only by {@link Client.Clutter.Batch.call_value} while the batch is open, so
	 * the flush looks at the map size.
	 *
	 * @param method wire method (e.g. ''Meta-Window.minimize'')
	 * @param instance leased stub; {@link OLLMrpc.Live.Interface.rpc_lid}
	 *     → {@link OLLMrpc.Request.lease_id}
	 * @param args GIR-order IN / INOUT args from {@link OLLMrpc.args}
	 * @param buffer optional client→server {@link OLLMrpc.Live.Buffer}
	 *     (memfd / SCM_RIGHTS); not pixel ''ay'' on the bin
	 * @return the peer response
	 */
	public OLLMrpc.Response call_value(
		string method,
		GLib.Object? instance = null,
		Gee.ArrayList<GLib.Value?>? args = null,
		OLLMrpc.Live.Buffer? buffer = null
	) throws GLib.Error {
		flush_prop(instance);
		uint64 lease_id = 0;
		if (instance != null) {
			lease_id = lease_id_of(instance, method);
		}
		var req = new OLLMrpc.Request() {
			method = method,
			lease_id = lease_id,
			buffer = buffer,
		};
		if (args == null) {
			return do_call(req);
		}
		foreach (var val in args) {
			if (!val.type().is_a(GLib.Type.OBJECT)) {
				req.args.add(val);
				continue;
			}
			var obj = val.get_object();
			if (obj == null) {
				var zero = GLib.Value(GLib.Type.UINT64);
				zero.set_uint64(0);
				req.args.add(zero);
				continue;
			}
			var lease = lease_id_of(obj, method);
			var wire = GLib.Value(GLib.Type.UINT64);
			wire.set_uint64(lease);
			req.args.add(wire);
		}
		return do_call(req);
	}

	public delegate Gee.ArrayList<GLib.Value?>? InvokeHandler(OLLMrpc.Live.Invoke call);

	public class InvokeRow : GLib.Object
	{
		public InvokeHandler handler;
	}

	public OLLMrpc.Client client;
	private bool connected = false;

	[CCode (cname = "gsr_client_clutter_register")]
	private extern void gsr_client_clutter_register();

	[CCode (cname = "gsr_client_meta_register")]
	private extern void gsr_client_meta_register();

	[CCode (cname = "gsr_client_st_register")]
	private extern void gsr_client_st_register();

	[CCode (cname = "gsr_client_shell_register")]
	private extern void gsr_client_shell_register();

	public Gee.HashMap<int, InvokeRow>? handlers = null;

	/**
	 * Handlers queued while an actor binds virtuals during
	 * create. Null once those ids are filed.
	 */
	public Gee.ArrayList<InvokeRow>? hook_rows;

	/**
	 * C symbol of {@link Shell.Signals.pending_signals}.
	 *
	 * The clutter stub does not link shell-gi.
	 * {@link ensure_signal_subscribe} reads this on the next
	 * connect.
	 */
	[CCode (cname = "shell_signals_pending_signals", array_length_cname = "shell_signals_pending_signals_length1", array_length_type = "int")]
	public extern string[] pending_signals;

	/**
	 * Allocated length of {@link Shell.Signals.pending_signals}.
	 */
	[CCode (cname = "_shell_signals_pending_signals_size_")]
	public extern int pending_signals_size;

	// FIXME - THIS SHOULD USE SIGNAL DIRECT EVENTUALLY
	[CCode (cname = "shell_signals_connect")]
	private extern int shell_signals_connect(
		GLib.Object obj, string signal_name, int gjs_handler_id);

	[CCode (cname = "shell_signals_disconnect")]
	private extern void shell_signals_disconnect(
		GLib.Object obj, string signal_name);

	/**
	 * Insert create-time proxy into {@link OLLMrpc.Client.proxies}.
	 *
	 * OPC {@code parse_object} reuses that map; without this, the first
	 * decode of a client-minted lid still remints and GJS {@code ===}
	 * breaks (messageList Cover/Header).
	 */
	public void register_handle(GLib.Object obj)
	{
		var handle = obj as OLLMrpc.Live.Interface;
		if (handle == null || handle.rpc_lid == 0 || client == null) {
			return;
		}
		client.proxies.set((int) handle.rpc_lid, obj);
	}

	/**
	 * Vala stub path into {@link Shell.Signals.connect}. mutter-rpc /
	 * st-rpc cannot link shell-gi. Lazy-bound ({@code --unresolved-symbols}).
	 *
	 * Passes GJS handler id 0: this is not the GJS wrap. Call sites either
	 * pre-subscribe so a later GJS {@code .connect()} can re-emit, or they
	 * {@code signal_*.connect()} themselves in Vala. {@link Shell.Signals}
	 * mints its own handler id when this is 0. Not deprecated — the
	 * trampoline stays until gi-stub can call Shell.Signals directly.
	 */
	public void ensure_signal_subscribe(GLib.Object obj, string signal_name)
	{
		shell_signals_connect(obj, signal_name, 0);
	}

	/**
	 * Vala stub path into {@link Shell.Signals.disconnect}.
	 */
	public void ensure_signal_unsubscribe(GLib.Object obj, string signal_name)
	{
		shell_signals_disconnect(obj, signal_name);
	}

	/**
	 * Register Ui wire types and connect to {@code MUTTER_RPC_SOCKET}.
	 *
	 * Safe to call repeatedly; returns immediately if already connected.
	 */
	public void register()
	{
		if (connected) {
			return;
		}

		Gsr.Shared.rpc_register();
		OLLMrpc.Daemon.rpc_register();
		gsr_client_clutter_register();
		gsr_client_meta_register();
		gsr_client_st_register();
		gsr_client_shell_register();

		var socket_path = GLib.Environment.get_variable("MUTTER_RPC_SOCKET");
		if (socket_path == null || socket_path.length == 0) {
			var runtime = GLib.Environment.get_variable("XDG_RUNTIME_DIR");
			if (runtime != null && runtime.length > 0) {
				socket_path = GLib.Path.build_filename(runtime, "mutter-rpc.sock");
			} else {
				socket_path = "/tmp/mutter-rpc.sock";
			}
		}
		GLib.debug("mutter socket path %s", socket_path);

		client = new OLLMrpc.Client("", "", socket_path) {
			live_handles = true,
			/* OLLMrpc default is true; keep it. Never hard-disable. */
			debug = true,
		};
		client.invoke.connect((call) => {
			GLib.debug("invoke ENTER id=%d reply_id=%d",
				call.id, call.reply_id);
			Gee.ArrayList<GLib.Value?>? extra = null;
			if (handlers != null && handlers.has_key(call.id)) {
				extra = handlers.get(call.id).handler(call);
			} else {
				GLib.warning("Live.Invoke id=%d has no handler", call.id);
			}
			/*
			 * Reply in-flow via call_poll. Nested call_poll is supported
			 * (Live.Invoke mid-wait → RPC-Live-Callback.reply). Do not
			 * Idle-defer or queue — default Idle never runs during a
			 * sync poll burst and deadlocks Hook.emit.
			 */
			var reply_id = (uint64) call.reply_id;
			GLib.debug("invoke REPLY start id=%d reply_id=%llu extra=%s",
				call.id, reply_id,
				extra == null ? "null" : extra.size.to_string());
			try {
				if (extra == null) {
					Gsr.Client.Rpc.call_value("RPC-Live-Callback.reply",
						null,
						OLLMrpc.args("t", reply_id));
				} else {
					var reply = OLLMrpc.args("t", reply_id);
					foreach (var v in extra) {
						reply.add(v);
					}
					Gsr.Client.Rpc.call_value("RPC-Live-Callback.reply", null, reply);
				}
				GLib.debug("invoke REPLY done id=%d reply_id=%llu",
					call.id, reply_id);
			} catch (GLib.Error e) {
				/* LiveCallback.reply_error — Hook already completed. */
				GLib.debug("invoke REPLY error id=%d reply_id=%llu: %s",
					call.id, reply_id, e.message);
			}
		});
		client.notification.connect((notif) => {
			if (notif.method == "RPC-Live-Callback.unregister") {
				if (handlers != null) {
					handlers.unset(notif.id);
				}
			}
		});

		var connect_ok = false;
		var connect_err = "";
		var connect_loop = new GLib.MainLoop();
		client.connect.begin(new OLLMrpc.Request() {
			method = "RPC-Daemon.hello",
			args = OLLMrpc.args("is", 1, "meta-mini"),
		}, null, (obj, res) => {
			connect_ok = client.connect.end(res);
			if (!connect_ok) {
				connect_err = client.connect_error;
			}
			connect_loop.quit();
		});
		connect_loop.run();
		if (!connect_ok) {
			GLib.error("%s", connect_err);
		}
		connected = true;
	}

	/**
	 * Register a client handler and return the live callback id.
	 *
	 * While {@link hook_rows} is set, the handler is queued and
	 * this returns 1 so a zero id still means not bound.
	 * Otherwise one ''RPC-Live-Callback.register'' runs and the
	 * reply id is returned.
	 *
	 * An incoming {@link OLLMrpc.Live.Invoke} runs the handler,
	 * then ''RPC-Live-Callback.reply''.
	 *
	 * @param handler demux for one callback id
	 * @return wire callback id
	 */
	public uint64 callback_bind(owned InvokeHandler handler)
	{
		if (hook_rows != null) {
			var row = new InvokeRow();
			row.handler = (owned) handler;
			hook_rows.add(row);
			return 1;
		}
		register();
		if (handlers == null) {
			handlers = new Gee.HashMap<int, InvokeRow>();
		}
		var response = Gsr.Client.Rpc.call_value("RPC-Live-Callback.register");
		var id = response.args.get(0).get_uint64();
		var row = new InvokeRow();
		row.handler = (owned) handler;
		handlers.set((int) id, row);
		return id;
	}

	/**
	 * Remove a handler registered by {@link callback_bind} on both peers.
	 */
	public void callback_unbind(uint64 callback_id)
	{
		if (handlers == null
			|| !handlers.has_key((int) callback_id)) {
			return;
		}
		Gsr.Client.Rpc.call_value("RPC-Live-Callback.unregister", null,
			OLLMrpc.args("t", callback_id));
		handlers.unset((int) callback_id);
	}

	/**
	 * Pack leased stubs into a Variant ''at'' for typelib GLIST / GSLIST IN.
	 *
	 * Server {@code Gi.convert_list} resolves each id via connection leases.
	 *
	 * @param list owned or null GSList of leased GObjects
	 * @return empty ''at'' when list is null or empty
	 */
	public GLib.Variant lease_ids_at_slist(GLib.SList<GLib.Object>? list) throws GLib.Error
	{
		var builder = new GLib.VariantBuilder(new GLib.VariantType("at"));
		for (unowned GLib.SList<GLib.Object>? node = list; node != null; node = node.next) {
			builder.add("t", lease_id_of(node.data));
		}
		return builder.end();
	}

	/**
	 * Pack leased stubs into a Variant ''at'' for typelib GLIST IN.
	 *
	 * @param list owned or null GList of leased GObjects
	 * @return empty ''at'' when list is null or empty
	 */
	public GLib.Variant lease_ids_at_list(GLib.List<GLib.Object>? list) throws GLib.Error
	{
		var builder = new GLib.VariantBuilder(new GLib.VariantType("at"));
		for (unowned GLib.List<GLib.Object>? node = list; node != null; node = node.next) {
			builder.add("t", lease_id_of(node.data));
		}
		return builder.end();
	}

	internal uint64 lease_id_of(GLib.Object obj, string? context = null) throws GLib.Error
	{
		var handle = obj as OLLMrpc.Live.Interface;
		if (handle == null || handle.rpc_lid == 0) {
			var where = context ?? "lease_ids_at";
			throw new GLib.IOError.FAILED("RPC %s: no rpc_lid on %s",
				where, obj.get_type().name());
		}
		return handle.rpc_lid;
	}

	/**
	 * Sync call; {@link OLLMrpc.Response.retval} object, or null.
	 *
	 * @param method wire method
	 * @param expected GType of the return object
	 * @param args GIR-order IN / INOUT args from {@link OLLMrpc.args}
	 * @return the return object, or null when retval is unset
	 * @throws GLib.Error the error from the remote function or RPC
	 */
	public GLib.Object? call_object(
		string method,
		GLib.Type expected,
		Gee.ArrayList<GLib.Value?>? args = null
	) throws GLib.Error {
		var response = Gsr.Client.Rpc.call_value(method, null, args);
		if (response.retval.type() == GLib.Type.INVALID) {
			return null;
		}
		var obj = response.retval.get_object();
		if (!obj.get_type().is_a(expected)) {
			GLib.error("RPC %s: expected %s, got %s",
				method, expected.name(), obj.get_type().name());
		}
		return obj;
	}

	/**
	 * Sync call; every object in {@link OLLMrpc.Response.retval}.
	 *
	 * @param method wire method
	 * @param elem GType of each list row
	 * @param args GIR-order IN / INOUT args from {@link OLLMrpc.args}
	 * @return every list row (empty when retval is unset)
	 * @throws GLib.Error the error from the remote function or RPC
	 */
	public GLib.List<GLib.Object> call_list(
		string method,
		GLib.Type elem,
		Gee.ArrayList<GLib.Value?>? args = null
	) throws GLib.Error {
		var response = Gsr.Client.Rpc.call_value(method, null, args);
		var list = new GLib.List<GLib.Object>();
		if (response.retval.type() == GLib.Type.INVALID) {
			return list;
		}
		var rows = (Gee.ArrayList<GLib.Object>) response.retval.get_object();
		for (var i = 0; i < rows.size; i++) {
			var obj = rows.get(i);
			if (!obj.get_type().is_a(elem)) {
				GLib.error("RPC retval[%d]: expected %s, got %s",
					i, elem.name(), obj.get_type().name());
			}
			list.append(obj);
		}
		return list;
	}

	internal OLLMrpc.Response do_call(OLLMrpc.Request request) throws GLib.Error
	{
		register();
		/* call_poll: block on socket poll without iterating the default
		 * MainContext (avoids Gvc/Pulse mid-stub; volume.js _output race).
		 * Nested call_poll is OK for Live.Invoke → reply. */
		return client.call_poll(request);
	}
}
