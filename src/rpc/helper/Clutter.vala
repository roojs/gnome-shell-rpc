/**
 * Helper-Clutter — namespace Clutter functions that need packed returns
 * (Compact {@link Clutter.Event} cannot go through Gi.dispatch).
 *
 * Class must not be named {@code Clutter} — that shadows the Clutter
 * namespace inside {@code GnomeShellRpc.Rpc.Helper} (Display.vala etc.).
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class ClutterHelper : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Clutter", typeof(ClutterHelper),
				"get_current_event", "",
				null
			);
			OLLMrpc.Request.register_live("Helper-Clutter", new ClutterHelper());
		}

		/**
		 * Pack stock {@code clutter_get_current_event} as
		 * type / x / y / button / state / keyval ({@code iddduu}); empty args = none.
		 */
		public void get_current_event(OLLMrpc.Request request)
		{
			unowned var ev = Clutter.get_current_event();
			if (ev == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			float x = 0f, y = 0f;
			ev.get_coords(out x, out y);
			var et = ev.get_type();
			uint32 button = 0;
			if (et == Clutter.EventType.BUTTON_PRESS
					|| et == Clutter.EventType.BUTTON_RELEASE
					|| et == Clutter.EventType.PAD_BUTTON_PRESS
					|| et == Clutter.EventType.PAD_BUTTON_RELEASE) {
				button = ev.get_button();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("iddduu",
					(int) et, (double) x, (double) y, button,
					(uint) ev.get_state(), ev.get_key_symbol()),
			});
		}
	}
}
