/**
 * Delivers {@code St.FocusManager.navigate_from_event} — rebuild a stock
 * key {@link Clutter.Event} from type / keyval / state and call libst.
 *
 * Wire prefix {@code Helper-FocusManager}. Uses exported
 * {@code clutter_event_key_new} via {@code gsr_clutter_event_key_new}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class FocusManager : GLib.Object
	{
		[CCode (cname = "gsr_clutter_event_key_new", cheader_filename = "gsr-clutter-event-key.h")]
		private static extern Clutter.Event gsr_clutter_event_key_new(
			Clutter.EventType type,
			uint32 keyval,
			Clutter.ModifierType modifiers
		);

		[CCode (cname = "st_focus_manager_navigate_from_event")]
		private static extern bool st_focus_manager_navigate_from_event(
			GLib.Object manager,
			Clutter.Event event
		);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-FocusManager", typeof(FocusManager),
				"navigate_from_event", "iuu",
				null
			);
			OLLMrpc.Request.register_live(
				"Helper-FocusManager", new FocusManager());
		}

		/**
		 * {@code Helper-FocusManager.navigate_from_event}.
		 *
		 * @param request inbound RPC (lease = FocusManager)
		 * @param event_type {@link Clutter.EventType} (must be KEY_PRESS)
		 * @param keyval key symbol
		 * @param state modifier bits
		 */
		public void navigate_from_event(
			OLLMrpc.Request request,
			int event_type,
			uint keyval,
			uint state
		) {
			var manager = (GLib.Object) request.connection.leases.get(
				(int) request.lease_id);
			var ev = gsr_clutter_event_key_new(
				(Clutter.EventType) event_type,
				keyval,
				(Clutter.ModifierType) state
			);
			var ok = false;
			if (ev != null) {
				ok = st_focus_manager_navigate_from_event(manager, ev);
				ev.free();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
			});
		}
	}
}
