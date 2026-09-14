/**
 * Delivers {@link Meta.Display} Override RPC (plan 0.5.6 B1).
 *
 * Wire prefix ''Helper-Display''. Lease is the display for
 * {@link add_keybinding}. {@link keybindings_set_custom_handler} is a
 * namespace function — no lease. {@link GLib.Settings} crosses as schema id
 * (same packing as C1 file URI). {@link Clutter.Event} / {@link Meta.KeyBinding}
 * on notify are not packed yet; the trampoline still fires.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Display : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Display", typeof(Display),
				"add_keybinding", "ssut",
				"keybindings_set_custom_handler", "st",
				"request_pad_osd", "osb",
				"get_pad_button_label", "osi",
				"get_pad_feature_label", "osiui",
				null
			);
			OLLMrpc.Request.register_live("Helper-Display",
				 new Display());
		}

		public void add_keybinding(
			OLLMrpc.Request request,
			string name,
			string schema_id,
			uint flags,
			uint64 callback_id
		) {
			var display = (Meta.Display) request.connection.leases.get(
				(int) request.lease_id);
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				GLib.warning("unknown callback id");
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("u", (uint) 0),
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			var source = GLib.SettingsSchemaSource.get_default();
			var schema = source.lookup(schema_id, true);
			if (schema == null) {
				GLib.warning(
					"Helper-Display.add_keybinding: schema '%s' is not installed",
					schema_id
				);
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("u", (uint) 0),
				});
				return;
			}
			var settings = new GLib.Settings.full(schema, null, null);
			var action = display.add_keybinding(
				name, settings, (Meta.KeyBindingFlags) flags,
				(d, w, event, binding) => {
					uint64 win_h = 0;
					if (w != null) {
						win_h = row.connection.export(w);
					}
					row.emit(OLLMrpc.args("tt",
						row.connection.export(d), win_h));
				});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("u", action),
			});
		}

		public void keybindings_set_custom_handler(
			OLLMrpc.Request request,
			string name,
			uint64 callback_id
		) {
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				GLib.warning("unknown callback id");
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", false),
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			var ok = Meta.KeyBinding.set_custom_handler(name,
				(d, w, event, binding) => {
					uint64 win_h = 0;
					if (w != null) {
						win_h = row.connection.export(w);
					}
					row.emit(OLLMrpc.args("tt",
						row.connection.export(d), win_h));
				});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
			});
		}

		public void request_pad_osd(
			OLLMrpc.Request request,
			Clutter.InputDevice? pad,
			string device_name,
			bool edition_mode
		) {
			var display = (Meta.Display) request.connection.leases.get(
				(int) request.lease_id);
			var device = Devices.resolve(pad, device_name, true);
			if (device != null) {
				display.request_pad_osd(device, edition_mode);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void get_pad_button_label(
			OLLMrpc.Request request,
			Clutter.InputDevice? pad,
			string device_name,
			int button_number
		) {
			var display = (Meta.Display) request.connection.leases.get(
				(int) request.lease_id);
			var device = Devices.resolve(pad, device_name, true);
			var label = "";
			if (device != null) {
				label = display.get_pad_button_label(device, button_number);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("s", label),
			});
		}

		public void get_pad_feature_label(
			OLLMrpc.Request request,
			Clutter.InputDevice? pad,
			string device_name,
			int feature,
			uint direction,
			int feature_number
		) {
			var display = (Meta.Display) request.connection.leases.get(
				(int) request.lease_id);
			var device = Devices.resolve(pad, device_name, true);
			var label = "";
			if (device != null) {
				label = display.get_pad_feature_label(device,
					(Meta.PadFeatureType) feature,
					(Meta.PadDirection) direction, feature_number);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("s", label),
			});
		}
	}
}
