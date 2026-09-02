/**
 * Sync RPC client for GI stubs (plan 0.5 Meta mini).
 *
 * {@link register} is idempotent (wire types + {@code MUTTER_RPC_SOCKET}).
 * {@link call_values}, {@link call_object}, and {@link call_list} always start
 * with {@link register}.
 *
 * Positional args use {@link OLLMrpc.Request.args} (GIR order, no direction
 * on the wire). Instance stubs implement {@link OLLMrpc.Live.Handle};
 * {@link OLLMrpc.Live.Handle.rpc_lid} → {@link OLLMrpc.Request.lease_id}.
 * The C return lands in {@link OLLMrpc.Response.retval}. OUT / INOUT
 * scalars land in {@link OLLMrpc.Response.args}.
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

		private static string gobject_prop_from_member(string member)
		{
			var sb = new GLib.StringBuilder();
			for (var i = 0; i < member.length; i++) {
				var c = member[i];
				if (c == '_') {
					sb.append_c('-');
				} else {
					sb.append_c(c);
				}
			}
			return sb.str;
		}

		private static Gee.HashMap<ulong, Gee.HashMap<string, GLib.Value?>>? local_props = null;

		private static Gee.HashMap<string, GLib.Value?> local_props_for(GLib.Object instance)
		{
			if (Runtime.local_props == null) {
				Runtime.local_props =
					new Gee.HashMap<ulong, Gee.HashMap<string, GLib.Value?>>();
			}
			var key = (ulong) instance;
			if (!Runtime.local_props.has_key(key)) {
				Runtime.local_props.set(
					key, new Gee.HashMap<string, GLib.Value?>());
			}
			return Runtime.local_props.get(key);
		}

		private static GLib.Value wire_retval(GLib.Value val, GLib.ParamSpec pspec)
		{
			if (val.type().is_a(GLib.Type.ENUM) || val.type().is_a(GLib.Type.FLAGS)) {
				var wire = GLib.Value(GLib.Type.INT);
				wire.set_int(val.get_enum());
				return wire;
			}
			if (pspec.value_type.is_a(GLib.Type.ENUM)
					|| pspec.value_type.is_a(GLib.Type.FLAGS)) {
				var wire = GLib.Value(GLib.Type.INT);
				wire.set_int(val.get_enum());
				return wire;
			}
			return val;
		}

		/**
		 * TEMP: local GJS / St actors without a lease — shadow GObject props
		 * (get_/set_/is_). Boot probe; not the long-term model.
		 */
		private static OLLMrpc.Response call_local(
			GLib.Object instance,
			string method,
			Gee.ArrayList<GLib.Value?>? args
		) {
			var dot = method.last_index_of(".");
			if (dot < 0) {
				GLib.error(
					"RPC %s: local %s — bad method",
					method, instance.get_type().name());
			}
			var member = method.substring(dot + 1);
			var response = new OLLMrpc.Response();
			var bag = Runtime.local_props_for(instance);

			if (member.has_prefix("set_") && args != null && args.size >= 1) {
				var prop_name = Runtime.gobject_prop_from_member(
					member.substring(4));
				bag.set(prop_name, args[0]);
				return response;
			}
			if (member.has_prefix("get_") || member.has_prefix("is_")) {
				var start = member.has_prefix("get_") ? 4 : 3;
				var prop_name = Runtime.gobject_prop_from_member(
					member.substring(start));
				var pspec = instance.get_class().find_property(prop_name);
				if (pspec == null) {
					GLib.error(
						"RPC %s: local %s — no property %s",
						method, instance.get_type().name(), prop_name);
				}
				if (bag.has_key(prop_name)) {
					response.retval = Runtime.wire_retval(
						bag.get(prop_name), pspec);
					return response;
				}
				response.retval = Runtime.wire_retval(
					pspec.get_default_value(), pspec);
				return response;
			}
			GLib.error(
				"RPC %s: local %s — unhandled member",
				method, instance.get_type().name());
		}

		private static uint64 lease_id_of(GLib.Object obj, string? context = null)
		{
			var handle = obj as OLLMrpc.Live.Handle;
			if (handle == null || handle.rpc_lid == 0) {
				if (context != null) {
					GLib.error("RPC %s: no rpc_lid on %s",
						context, obj.get_type().name());
				}
				GLib.error(
					"RPC lease_ids_at: no rpc_lid on %s",
					obj.get_type().name()
				);
			}
			return handle.rpc_lid;
		}

		/**
		 * Sync call with positional {@link GLib.Value}s and optional instance.
		 *
		 * @param method wire method (e.g. {@code Meta-Window.minimize})
		 * @param instance leased stub; {@link OLLMrpc.Live.Handle.rpc_lid}
		 *     → {@link OLLMrpc.Request.lease_id}
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
				var handle = instance as OLLMrpc.Live.Handle;
			if (handle != null && handle.rpc_lid == 0) {
				return Runtime.call_local(instance, method, args);
			}
				lease_id = Runtime.lease_id_of(instance, method);
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
				var arg_handle = obj as OLLMrpc.Live.Handle;
				if (arg_handle != null && arg_handle.rpc_lid == 0) {
					var zero = GLib.Value(GLib.Type.UINT64);
					zero.set_uint64(0);
					req.args.add(zero);
					continue;
				}
				var lease = Runtime.lease_id_of(obj, method);
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
