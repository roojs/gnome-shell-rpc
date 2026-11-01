/**
 * Server peer for {@link global::Clutter.Backend} sprite lookup.
 *
 * Shell 50 calls {@code get_sprite} and {@code get_pointer_sprite},
 * then passes that sprite to {@code Meta.Window.begin_grab_op}.
 * The 18 startup calls {@link rpc_register}. The 16 build does not.
 */
namespace Gsr.Server.Clutter
{
	public class Backend : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Clutter-Backend", typeof(Backend),
				"get_sprite", "tuu",
				"get_pointer_sprite", "t",
				null
			);
			OLLMrpc.Request.register_live("Clutter-Backend", new Backend());
		}

		/**
		 * ''Clutter-Backend.get_sprite'' — stock
		 * {@code clutter_backend_get_sprite} for the current event
		 * when its type and time match the client event.
		 *
		 * @param request inbound RPC; lease is the backend
		 * @param stage_lid lease of the stage
		 * @param event_type client {@link global::Clutter.EventType}
		 * @param time client {@code clutter_event_get_time}
		 */
		public void get_sprite(
			OLLMrpc.Request request,
			uint64 stage_lid,
			uint event_type,
			uint time
		) {
			var backend = request.connection.leases.get((int) request.lease_id)
				as global::Clutter.Backend;
			var stage = request.connection.leases.get((int) stage_lid)
				as global::Clutter.Stage;
			if (backend == null || stage == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			unowned global::Clutter.Event? ev = global::Clutter.get_current_event();
			uint64 lid = 0;
			if (ev != null && ev.get_type() == (global::Clutter.EventType) event_type
				&& ev.get_time() == time) {
				var sprite = backend.get_sprite(stage, ev);
				if (sprite != null) {
					lid = (uint64) request.connection.export(sprite);
				}
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", lid),
			});
		}

		/**
		 * ''Clutter-Backend.get_pointer_sprite'' — stock
		 * {@code clutter_backend_get_pointer_sprite}.
		 *
		 * @param request inbound RPC; lease is the backend
		 * @param stage_lid lease of the stage
		 */
		public void get_pointer_sprite(OLLMrpc.Request request, uint64 stage_lid)
		{
			var backend = request.connection.leases.get((int) request.lease_id)
				as global::Clutter.Backend;
			var stage = request.connection.leases.get((int) stage_lid)
				as global::Clutter.Stage;
			if (backend == null || stage == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var sprite = backend.get_pointer_sprite(stage);
			uint64 lid = 0;
			if (sprite != null) {
				lid = (uint64) request.connection.export(sprite);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", lid),
			});
		}
	}
}
