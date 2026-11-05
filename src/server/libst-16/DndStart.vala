/**
 * Server peer for stock {@code St.DndStartGesture}.
 *
 * The two getters return a compact {@code Clutter.Event}. The client
 * rebuilds it with {@link Clutter.event_from_values}. Mutter 18 only:
 * the 16 build does not compile this file. libst has no installable
 * vapi, so the calls are C externs, same as {@link ThemeContext}.
 *
 * Wire prefix ''Gsr-St-DndStartGesture''.
 */
namespace Gsr.Server.St
{
	public class DndStart : GLib.Object
	{
		[CCode (cname = "st_dnd_start_gesture_get_drag_triggering_event")]
		private static extern unowned global::Clutter.Event?
			st_dnd_start_gesture_get_drag_triggering_event(GLib.Object gesture);

		[CCode (cname = "st_dnd_start_gesture_get_point_begin_event")]
		private static extern unowned global::Clutter.Event?
			st_dnd_start_gesture_get_point_begin_event(GLib.Object gesture);

		[CCode (cname = "st_dnd_start_gesture_get_type")]
		private static extern GLib.Type st_dnd_start_gesture_get_type();

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-St-DndStartGesture", typeof(DndStart),
				"create", "bu",
				"get_drag_triggering_event", "",
				"get_point_begin_event", "",
				null
			);
			OLLMrpc.Request.register_live("Gsr-St-DndStartGesture", new DndStart());
		}

		/**
		 * ''Gsr-St-DndStartGesture.create'' — lease of a new stock
		 * {@code St.DndStartGesture}. Shell 50 has no GIR constructor, so
		 * {@code g_object_new} is the mint. The two properties are the
		 * ones {@code dnd.js} passes to {@code new}.
		 *
		 * @param request inbound RPC; no lease yet
		 * @param manual_mode stock {@code manual-mode}
		 * @param timeout_threshold stock {@code timeout-threshold}, milliseconds
		 */
		public void create(
			OLLMrpc.Request request,
			bool manual_mode,
			uint timeout_threshold
		) {
			var created = GLib.Object.new(
				st_dnd_start_gesture_get_type(),
				"manual-mode", manual_mode,
				"timeout-threshold", timeout_threshold);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(created)),
			});
		}

		/**
		 * ''Gsr-St-DndStartGesture.get_drag_triggering_event'' — stock
		 * {@code st_dnd_start_gesture_get_drag_triggering_event}.
		 *
		 * @param request inbound RPC; lease is the gesture
		 */
		public void get_drag_triggering_event(OLLMrpc.Request request)
		{
			var gesture = request.connection.leases.get((int) request.lease_id) as GLib.Object;
			var events = OLLMrpc.Request.handlers.get("Gsr-Clutter") as Gsr.Server.Clutter.Clutter;
			if (gesture == null || events == null) {
				request.connection.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			events.reply_event(request, st_dnd_start_gesture_get_drag_triggering_event(gesture));
		}

		/**
		 * ''Gsr-St-DndStartGesture.get_point_begin_event'' — stock
		 * {@code st_dnd_start_gesture_get_point_begin_event}.
		 *
		 * @param request inbound RPC; lease is the gesture
		 */
		public void get_point_begin_event(OLLMrpc.Request request)
		{
			var gesture = request.connection.leases.get((int) request.lease_id) as GLib.Object;
			var events = OLLMrpc.Request.handlers.get("Gsr-Clutter") as Gsr.Server.Clutter.Clutter;
			if (gesture == null || events == null) {
				request.connection.reply_error(request, (int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			events.reply_event(request, st_dnd_start_gesture_get_point_begin_event(gesture));
		}
	}
}
