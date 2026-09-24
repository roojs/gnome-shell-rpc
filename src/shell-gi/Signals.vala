/**
 * gnome-shell-rpc named-signal subscribe and client re-emit (not stock Shell).
 *
 * {@code connect} does not {@code g_signal_connect}. Local handlers are
 * attached by the GJS wrap ({@code orig.connect}) or by Vala stubs. This
 * class records the name, tells the server
 * {@code RPC-Live-Subscribe.rpc_signal}, and re-emits on Notification.
 *
 * Two different ints:
 *
 * - GJS handler id — what {@code orig.connect} returned, what
 *   {@code obj.disconnect(id)} takes. Parameter {@code gjs_handler_id}.
 * - Our handler id — minted by {@link next_handler_id} because this class
 *   never registered a GLib signal, so it has no native id of its own.
 *
 * GJS wrap: {@code connect(obj, name, gjs_handler_id)} then
 * {@code disconnect_id(obj, gjs_handler_id)}. Vala stubs still call
 * {@link GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe}
 * (C trampoline — mutter-rpc / st-rpc cannot link shell-gi).
 */
namespace Shell
{
	public class Signals : GLib.Object
	{
		static construct {
			OLLMrpc.Bin.TypeOverride.register(new ClutterEventOverride());
		}

		/**
		 * Per lease: signal name → our handler id ({@link next_handler_id}).
		 *
		 * First connect of a name sends {@code RPC-Live-Subscribe.rpc_signal}.
		 * Notifications re-emit when {@code has_key(notif.method)}.
		 FIXME = SIGNALS SHOULD BE ID BASED ON THE WIRE - NOT STRINGS (AFTER REGISTRAITON)
		 */
		private static Gee.HashMap<int, Gee.HashMap<string, int>>? subs = null;

		/**
		 * Our handler id → how many local {@code .connect()}s share that name.
		 * Last drop (count 0) sends {@code RPC-Live-Subscribe.unsubscribe}.
		 */
		private static Gee.HashMap<int, int>? refs = null;

		/**
		 * GJS id map. Per lease: GJS handler id → our handler id.
		 *
		 * {@code obj.disconnect(id)} only has the GJS id. Int-to-int so that
		 * path never looks up by name.
		 */
		private static Gee.HashMap<int, Gee.HashMap<int, int>>? gjs_ids = null;

		/**
		 * Next of our handler ids, for a new named subscribe.
		 *
		 * GJS keeps its own id from {@code orig.connect} for
		 * {@code obj.disconnect}; Vala stubs pass {@code gjs_handler_id} 0.
		 * We mint ours so {@link refs} can key off an int (the name table is
		 * the FIXME). 0 is reserved: no lease.
		 */
		private static int next_handler_id = 1;

		[CCode (cname = "g_signal_emitv", cheader_filename = "glib-object.h")]
		private static extern void emitv(
			[CCode (array_length = false)] GLib.Value[] instance_and_params,
			uint signal_id,
			GLib.Quark detail,
			void* return_value);

		[CCode (cname = "shell_signals_connect")]
		public static int connect(GLib.Object obj, string signal_name, int gjs_handler_id = 0)
		{
			// HACK - if this increases we need to look for alterntives
			if (signal_name == "init-xserver") {
				return 0;
			}
			GnomeShellRpc.GiStub.Runtime.register();
			var handle = obj as OLLMrpc.Live.Handle;
			if (handle == null || handle.rpc_lid == 0) {
				return 0;
			}
			var lid = (int) handle.rpc_lid;
			if (Signals.subs != null
					&& Signals.subs.has_key(lid)
					&& Signals.subs.get(lid).has_key(signal_name)) {
				var hid = Signals.subs.get(lid).get(signal_name);
				Signals.refs.set(hid, Signals.refs.get(hid) + 1);
				if (gjs_handler_id != 0) {
					if (Signals.gjs_ids == null) {
						Signals.gjs_ids = new Gee.HashMap<int, Gee.HashMap<int, int>>();
					}
					if (!Signals.gjs_ids.has_key(lid)) {
						Signals.gjs_ids.set(lid, new Gee.HashMap<int, int>());
					}
					Signals.gjs_ids.get(lid).set(gjs_handler_id, hid);
				}
				return hid;
			}
			GnomeShellRpc.GiStub.Runtime.client.proxies.set(lid, obj);
			GnomeShellRpc.call_value("RPC-Live-Subscribe.rpc_signal", obj,
				OLLMrpc.args("s", signal_name));
			if (Signals.subs == null) {
				Signals.subs = new Gee.HashMap<int, Gee.HashMap<string, int>>();
				Signals.refs = new Gee.HashMap<int, int>();
				GnomeShellRpc.GiStub.Runtime.client.notification.connect((notif) => {
					if (Signals.subs == null
							|| !Signals.subs.has_key(notif.id)
							|| !Signals.subs.get(notif.id).has_key(notif.method)) {
						return;
					}
					if (!GnomeShellRpc.GiStub.Runtime.client.proxies.has_key(notif.id)) {
						return;
					}
					var target = GnomeShellRpc.GiStub.Runtime.client.proxies.get(notif.id);
					Signals.emit(target, notif.method, notif.args);
				});
			}
			if (!Signals.subs.has_key(lid)) {
				Signals.subs.set(lid, new Gee.HashMap<string, int>());
			}
			var hid = Signals.next_handler_id++;
			Signals.subs.get(lid).set(signal_name, hid);
			Signals.refs.set(hid, 1);
			if (gjs_handler_id != 0) {
				if (Signals.gjs_ids == null) {
					Signals.gjs_ids = new Gee.HashMap<int, Gee.HashMap<int, int>>();
				}
				if (!Signals.gjs_ids.has_key(lid)) {
					Signals.gjs_ids.set(lid, new Gee.HashMap<int, int>());
				}
				Signals.gjs_ids.get(lid).set(gjs_handler_id, hid);
			}
			return hid;
		}

		[CCode (cname = "shell_signals_disconnect")]
		public static void disconnect(GLib.Object obj, string signal_name)
		{
			var handle = obj as OLLMrpc.Live.Handle;
			if (handle == null || handle.rpc_lid == 0
					|| Signals.subs == null) {
				return;
			}
			var lid = (int) handle.rpc_lid;
			if (!Signals.subs.has_key(lid)
					|| !Signals.subs.get(lid).has_key(signal_name)) {
				return;
			}
			var hid = Signals.subs.get(lid).get(signal_name);
			var n = Signals.refs.get(hid) - 1;
			if (n > 0) {
				Signals.refs.set(hid, n);
				return;
			}
			GnomeShellRpc.call_value("RPC-Live-Subscribe.unsubscribe", obj,
				OLLMrpc.args("s", signal_name));
			Signals.refs.unset(hid);
			Signals.subs.get(lid).unset(signal_name);
		}

		[CCode (cname = "shell_signals_disconnect_id")]
		public static void disconnect_id(GLib.Object obj, int gjs_handler_id)
		{
			var handle = obj as OLLMrpc.Live.Handle;
			if (handle == null || handle.rpc_lid == 0
					|| Signals.gjs_ids == null) {
				return;
			}
			var lid = (int) handle.rpc_lid;
			if (!Signals.gjs_ids.has_key(lid)
					|| !Signals.gjs_ids.get(lid).has_key(gjs_handler_id)) {
				return;
			}
			var hid = Signals.gjs_ids.get(lid).get(gjs_handler_id);
			Signals.gjs_ids.get(lid).unset(gjs_handler_id);
			var n = Signals.refs.get(hid) - 1;
			if (n > 0) {
				Signals.refs.set(hid, n);
				return;
			}
			var table = Signals.subs.get(lid);
			var signal_name = "";
			foreach (var name in table.keys) {
				if (table.get(name) == hid) {
					signal_name = name;
					break;
				}
			}
			GnomeShellRpc.call_value("RPC-Live-Subscribe.unsubscribe", obj,
				OLLMrpc.args("s", signal_name));
			Signals.refs.unset(hid);
			table.unset(signal_name);
		}

		private static void emit(
			GLib.Object obj,
			string signal_name,
			Gee.ArrayList<GLib.Value?> args
		) {
			uint signal_id = 0;
			GLib.Quark detail = 0;
			if (!GLib.Signal.parse_name(signal_name, obj.get_type(),
					out signal_id, out detail, false)
					|| signal_id == 0) {
				return;
			}
			GLib.SignalQuery query;
			GLib.Signal.query(signal_id, out query);
			var n = 1 + (int) query.n_params;
			var vals = new GLib.Value[n];
			vals[0] = GLib.Value(obj.get_type());
			vals[0].set_object(obj);
			for (var i = 0; i < (int) query.n_params; i++) {
				vals[i + 1] = GLib.Value(query.param_types[i]);
			}
			var fields = args;
			if (fields == null) {
				fields = new Gee.ArrayList<GLib.Value?>();
			}
			OLLMrpc.Bin.TypeOverride.fill_params(query.param_types, fields, vals);
			for (var i = 0; i < (int) query.n_params; i++) {
				if (query.param_types[i] != typeof(Clutter.Frame)) {
					continue;
				}
				if (vals[i + 1].get_boxed() != null) {
					continue;
				}
				vals[i + 1].set_boxed(new Clutter.Frame());
			}
			Signals.emitv(vals, signal_id, detail, null);
		}
	}
}
