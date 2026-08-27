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
		public static void register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Display", typeof(Display),
				"add_keybinding", "ssut",
				"keybindings_set_custom_handler", "st",
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
					args = OLLMrpc.args("u", (uint) 0),
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			var settings = new GLib.Settings(schema_id);
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
				args = OLLMrpc.args("u", action),
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
					args = OLLMrpc.args("b", false),
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
				args = OLLMrpc.args("b", ok),
			});
		}
	}
}
