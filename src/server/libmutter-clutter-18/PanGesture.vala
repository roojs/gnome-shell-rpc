/**
 * Server peer for stock {@code Clutter.PanGesture}.
 *
 * The type is final, so this is not a subclass. {@code get_point_event}
 * returns a compact {@code Clutter.Event}, packed by {@link Clutter.reply_event}.
 * The 18 startup calls {@link rpc_register}. The 16 build does not.
 */
namespace Gsr.Server.Clutter
{
	public class PanGesture : GLib.Object
	{
		private Clutter? events;

		public static void rpc_register(Clutter events)
		{
			var helper = new PanGesture();
			helper.events = events;
			OLLMrpc.Request.add_class(
				"Gsr-Clutter-PanGesture", typeof(PanGesture),
				"create", "",
				"get_point_event", "i",
				null);
			OLLMrpc.Request.register_live("Gsr-Clutter-PanGesture", helper);
		}

		/**
		 * ''Gsr-Clutter-PanGesture.create'' — lease of a new stock pan gesture.
		 *
		 * @param request inbound RPC
		 */
		public void create(OLLMrpc.Request request)
		{
			var created = new global::Clutter.PanGesture();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", (uint64) request.connection.export(created)),
			});
		}

		/**
		 * ''Gsr-Clutter-PanGesture.get_point_event'' — stock
		 * {@code clutter_gesture_get_point_event}.
		 *
		 * @param request inbound RPC; lease is the pan gesture
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
