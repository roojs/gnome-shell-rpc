/**
 * Server peer for stock {@code Clutter.PressGesture}.
 *
 * The type is abstract, so this helper does not construct one. Click and
 * long-press gestures are press gestures. {@code get_point_event} returns a
 * compact {@code Clutter.Event}, packed by {@link Clutter.reply_event}.
 * The 18 startup calls {@link rpc_register}. The 16 build does not.
 */
namespace Gsr.Server.Clutter
{
	public class PressGesture : GLib.Object
	{
		private Clutter? events;

		public static void rpc_register(Clutter events)
		{
			var helper = new PressGesture();
			helper.events = events;
			OLLMrpc.Request.add_class(
				"Gsr-Clutter-PressGesture", typeof(PressGesture),
				"get_point_event", "i",
				null);
			OLLMrpc.Request.register_live("Gsr-Clutter-PressGesture", helper);
		}

		/**
		 * ''Gsr-Clutter-PressGesture.get_point_event'' — stock
		 * {@code clutter_gesture_get_point_event}.
		 *
		 * @param request inbound RPC; lease is the press gesture
		 * @param point_index index of the point
		 */
		public void get_point_event(OLLMrpc.Request request, int point_index)
		{
			var gesture = request.connection.leases.get((int) request.lease_id)
				as global::Clutter.Gesture;
			if (gesture == null || this.events == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			this.events.reply_event(request, gesture.get_point_event(point_index));
		}
	}
}
