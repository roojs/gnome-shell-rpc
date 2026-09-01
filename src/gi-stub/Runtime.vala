/**
 * Sync RPC client for GI stubs (plan 0.5 Meta mini).
 *
 * {@link register} is idempotent (wire types + {@code MUTTER_RPC_SOCKET}).
 * {@link call_values}, {@link call_object}, and {@link call_list} always start
 * with {@link register}.
 *
 * Positional args use {@link OLLMrpc.Request.args} (GIR order, no direction
 * on the wire). Instance stubs carry libocrpc {@code rpc-lid} qdata →
 * {@link OLLMrpc.Request.lease_id}. The C return lands in
 * {@link OLLMrpc.Response.retval}. OUT / INOUT scalars land in
 * {@link OLLMrpc.Response.args}.
 *
 * == Example ==
 *
 * {{{
 * GnomeShellRpc.GiStub.Runtime.register();
 * var rows = GnomeShellRpc.GiStub.Runtime.call_list("Meta-Display.list_windows",
 *     typeof(GnomeShellRpc.Ui.Window));
 * GnomeShellRpc.GiStub.Runtime.call_values("Meta-Window.minimize", win);
 * }}}
 */
namespace GnomeShellRpc.GiStub
{
	public class Runtime : GLib.Object
	{
		public static OLLMrpc.Client client;
		private static bool connected = false;

		[CCode (cname = "meta_register", cheader_filename = "meta-register.h")]
		private static extern void meta_register_bins();

		public delegate Gee.ArrayList<GLib.Value?>? 
			InvokeHandler(OLLMrpc.Live.Invoke call);

		private class InvokeRow : GLib.Object
		{
			public InvokeHandler handler;
		}

		private static Gee.HashMap<int, InvokeRow>? handlers = null;

		/**
		 * Register Ui wire types and connect to {@code MUTTER_RPC_SOCKET}.
		 *
		 * Safe to call repeatedly; returns immediately if already connected.
		 */
		public static void register()
		{
			if (Runtime.connected) {
				return;
			}

			GnomeShellRpc.Shared.Rectangle.rpc_register();
			GnomeShellRpc.Ui.Window.rpc_register();
			OLLMrpc.Daemon.rpc_register();
			Clutter.register();
			meta_register_bins();
			OLLMrpc.Bin.register("Clutter-ActorMeta", typeof(Clutter.ActorMeta));
			OLLMrpc.Bin.register("Clutter-Effect", typeof(Clutter.Effect));
			OLLMrpc.Bin.register(
				"Clutter-OffscreenEffect", typeof(Clutter.OffscreenEffect));

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

			Runtime.client = new OLLMrpc.Client("", "", socket_path) {
				live_handles = true,
				debug = false,
			};
			Runtime.client.invoke.connect((call) => {
				Gee.ArrayList<GLib.Value?>? extra = null;
				if (Runtime.handlers != null && Runtime.handlers.has_key(call.id)) {
					extra = Runtime.handlers.get(call.id).handler(call);
				} else {
					GLib.warning("Live.Invoke id=%d has no handler", call.id);
				}
				var reply_id = (uint64) call.reply_id;
				GLib.Idle.add(() => {
					if (extra == null) {
						Runtime.call_values("RPC-Live-Callback.reply", null,
							OLLMrpc.args("t", reply_id));
						return GLib.Source.REMOVE;
					}
					var reply = OLLMrpc.args("t", reply_id);
					foreach (var v in extra) {
						reply.add(v);
					}
					Runtime.call_values("RPC-Live-Callback.reply", null, reply);
					return GLib.Source.REMOVE;
				});
			});
			Runtime.client.notification.connect((notif) => {
				if (notif.method != "RPC-Live-Callback.unregister") {
					return;
				}
				if (Runtime.handlers != null) {
					Runtime.handlers.unset(notif.id);
				}
			});

			var connect_ok = false;
			var connect_err = "";
			var connect_loop = new GLib.MainLoop();
			Runtime.client.connect.begin(new OLLMrpc.Request() {
				method = "RPC-Daemon.hello",
				args = OLLMrpc.args("is", 1, "meta-mini"),
			}, null, (obj, res) => {
				connect_ok = Runtime.client.connect.end(res);
				if (!connect_ok) {
					connect_err = Runtime.client.connect_error;
				}
				connect_loop.quit();
			});
			connect_loop.run();
			if (!connect_ok) {
				GLib.error("%s", connect_err);
			}
			Runtime.connected = true;
		}

		/**
		 * Register a client handler and return the live callback id.
		 *
		 * Sends {@code RPC-Live-Callback.register}. Incoming
		 * {@link OLLMrpc.Live.Invoke} runs {@code handler} then
		 * {@code RPC-Live-Callback.reply} (handler return values after
		 * {@code reply_id}; void returns {@code null}).
		 *
		 * @param handler demux for one callback id
		 * @return wire callback id
		 */
		public static uint64 callback_bind(owned InvokeHandler handler)
		{
			Runtime.register();
			if (Runtime.handlers == null) {
				Runtime.handlers = new Gee.HashMap<int, InvokeRow>();
			}
			var response = Runtime.call_values("RPC-Live-Callback.register", null);
			var id = (int) response.args.get(0).get_uint64();
			var row = new InvokeRow();
			row.handler = (owned) handler;
			Runtime.handlers.set(id, row);
			return (uint64) id;
		}

		/**
		 * Pack leased stubs into a Variant ''at'' for typelib GLIST / GSLIST IN.
		 *
		 * Server {@code Gi.convert_list} resolves each id via connection leases.
		 *
		 * @param list owned or null GSList of leased GObjects
		 * @return empty ''at'' when list is null or empty
		 */
		public static GLib.Variant lease_ids_at_slist(GLib.SList<GLib.Object>? list)
		{
			var builder = new GLib.VariantBuilder(new GLib.VariantType("at"));
			for (unowned GLib.SList<GLib.Object>? node = list; node != null; node = node.next) {
				builder.add("t", Runtime.lease_id_of(node.data));
			}
			return builder.end();
		}

		/**
		 * Pack leased stubs into a Variant ''at'' for typelib GLIST IN.
		 *
		 * @param list owned or null GList of leased GObjects
		 * @return empty ''at'' when list is null or empty
		 */
		public static GLib.Variant lease_ids_at_list(GLib.List<GLib.Object>? list)
		{
			var builder = new GLib.VariantBuilder(new GLib.VariantType("at"));
			for (unowned GLib.List<GLib.Object>? node = list; node != null; node = node.next) {
				builder.add("t", Runtime.lease_id_of(node.data));
			}
			return builder.end();
		}

		private static uint64 lease_id_of(GLib.Object obj)
		{
			var lease = (uint64) obj.get_data<void*>("rpc-lid");
			if (lease == 0) {
				GLib.error(
					"RPC lease_ids_at: no rpc-lid on %s",
					obj.get_type().name()
				);
			}
			return lease;
		}

		/**
		 * Sync call with positional {@link GLib.Value}s and optional instance.
		 *
		 * @param method wire method (e.g. {@code Meta-Window.minimize})
		 * @param instance leased stub; {@code rpc-lid} → {@link OLLMrpc.Request.lease_id}
		 * @param args GIR-order IN / INOUT args from {@link OLLMrpc.args}
		 * @throws GLib.Error the error from the remote function or RPC
		 */
		public static OLLMrpc.Response call_values(
			string method,
			GLib.Object? instance = null,
			Gee.ArrayList<GLib.Value?>? args = null
		) throws GLib.Error {
			uint64 lease_id = 0;
			if (instance != null) {
				lease_id = (uint64) instance.get_data<void*>("rpc-lid");
				if (lease_id == 0) {
					GLib.error("RPC %s: no rpc-lid on %s",
						method, instance.get_type().name());
				}
			}
			var req = new OLLMrpc.Request() {
				method = method,
				lease_id = lease_id,
			};
			if (args == null) {
				return Runtime.do_call(req);
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
				var lease = (uint64) obj.get_data<void*>("rpc-lid");
				if (lease == 0) {
					GLib.error("RPC %s: cannot serialize %s (not a leased stub)",
						method, val.type().name());
				}
				var wire = GLib.Value(GLib.Type.UINT64);
				wire.set_uint64(lease);
				req.args.add(wire);
			}
			return Runtime.do_call(req);
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
		public static GLib.Object? call_object(
			string method,
			GLib.Type expected,
			Gee.ArrayList<GLib.Value?>? args = null
		) throws GLib.Error {
			var response = Runtime.call_values(method, null, args);
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
		public static GLib.List<GLib.Object> call_list(
			string method,
			GLib.Type elem,
			Gee.ArrayList<GLib.Value?>? args = null
		) throws GLib.Error {
			var response = Runtime.call_values(method, null, args);
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

		private static OLLMrpc.Response do_call(OLLMrpc.Request request) throws GLib.Error
		{
			Runtime.register();

			OLLMrpc.Response? response = null;
			GLib.Error? call_error = null;
			var call_loop = new GLib.MainLoop();
			Runtime.client.call.begin(request, (obj, res) => {
				try {
					response = Runtime.client.call.end(res);
				} catch (GLib.Error e) {
					call_error = e;
				}
				call_loop.quit();
			});
			call_loop.run();
			if (call_error != null) {
				throw call_error;
			}
			return response;
		}
	}
}
