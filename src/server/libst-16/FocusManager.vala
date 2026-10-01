/**
 * Delivers {@code global::St.FocusManager.navigate_from_event} — rebuild a stock
 * key {@link global::Clutter.Event} from type / keyval / state and call libst.
 *
 * Wire prefix {@code Gsr-St-FocusManager}. Uses exported
 * {@code clutter_event_key_new} via {@code gsr_clutter_event_key_new}.
 */
namespace Gsr.Server.St
{
	public class FocusManager : GLib.Object
	{
		[CCode (cname = "gsr_clutter_event_key_new", cheader_filename = "gsr-clutter-event-key.h")]
		private static extern global::Clutter.Event gsr_clutter_event_key_new(
			global::Clutter.EventType type,
			uint32 keyval,
			global::Clutter.ModifierType modifiers
		);

		[CCode (cname = "st_focus_manager_navigate_from_event")]
		private static extern bool st_focus_manager_navigate_from_event(
			GLib.Object manager,
			global::Clutter.Event event
		);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-St-FocusManager", typeof(FocusManager),
				"navigate_from_event", "iuu",
				null
			);
			OLLMrpc.Request.register_live(
				"Gsr-St-FocusManager", new FocusManager());
		}

		/**
		 * {@code Gsr-St-FocusManager.navigate_from_event}.
		 *
		 * @param request inbound RPC (lease = FocusManager)
		 * @param event_type {@link global::Clutter.EventType} (must be KEY_PRESS)
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
				(global::Clutter.EventType) event_type,
				keyval,
				(global::Clutter.ModifierType) state
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
