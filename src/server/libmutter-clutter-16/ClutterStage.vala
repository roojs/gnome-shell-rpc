/**
 * Clutter Stage Helper for C ABI gaps (libshell link).
 *
 * Wire prefix ''Clutter-Stage''. {@link get_view_at} returns the
 * view object. {@link paint_to_buffer} puts the frame on the
 * memfd reply buffer.
 * {@code get_view_at} is not in the mutter VAPI
 * ({@code introspectable=0}) — call stock C directly via {@code extern}.
 */
namespace Gsr.Server.Clutter
{
	public class ClutterStage : GLib.Object
	{
		[CCode (cname = "clutter_stage_get_view_at",
			cheader_filename = "clutter/clutter.h")]
		private static extern global::Clutter.StageView? clutter_stage_get_view_at(
			global::Clutter.Stage stage,
			float x,
			float y
		);

		public static void rpc_register()
		{
			/* GestureAction is mutter 16 only. The shared namespace
			 * calls this after Clutter.rpc_register. */
			var events = OLLMrpc.Request.handlers.get("Gsr-Clutter") as Clutter;
			if (events != null) {
				GestureAction.rpc_register(events);
				OLLMrpc.Bin.register_alias(
					"Clutter-GestureAction", typeof(GestureAction));
			}
			OLLMrpc.Request.add_class(
				"Clutter-Stage", typeof(ClutterStage),
				"get_view_at", "ff",
				"paint_to_buffer", "iiiifiiuu",
				null
			);
			OLLMrpc.Request.register_live("Clutter-Stage",
				new ClutterStage());
		}

		/**
		 * ''Clutter-Stage.get_view_at'' — the live stage view.
		 * Decode constructs the proxy with its lease set.
		 *
		 * @param request inbound RPC; lease is the stage
		 * @param x stage X
		 * @param y stage Y
		 */
		public void get_view_at(OLLMrpc.Request request, float x, float y)
		{
			var stage = (global::Clutter.Stage) request.connection.leases.get(
				(int) request.lease_id);
			var view = clutter_stage_get_view_at(stage, x, y);
			if (view == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			request.connection.export(view);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", view),
			});
		}

		/**
		 * ''Clutter-Stage.paint_to_buffer'' — frame on the memfd
		 * reply buffer.
		 *
		 * @param request inbound RPC; lease is the stage
		 * @param x rect X
		 * @param y rect Y
		 * @param width rect width
		 * @param height rect height
		 * @param scale capture scale
		 * @param n_bytes client buffer capacity
		 * @param stride row stride
		 * @param format Cogl pixel format
		 * @param paint_flags Clutter paint flags
		 */
		public void paint_to_buffer(
			OLLMrpc.Request request,
			int x,
			int y,
			int width,
			int height,
			float scale,
			int n_bytes,
			int stride,
			uint format,
			uint paint_flags
		) {
			var stage = (global::Clutter.Stage) request.connection.leases.get(
				(int) request.lease_id);
			Mtk.Rectangle rect = { x, y, width, height };
			var buf = new uint8[n_bytes];
			try {
				stage.paint_to_buffer(
					rect,
					scale,
					buf,
					stride,
					(Cogl.PixelFormat) format,
					(global::Clutter.PaintFlag) paint_flags
				);
			} catch (GLib.Error e) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e);
				return;
			}
			try {
				var buffer = new OLLMrpc.Live.Buffer.from_bytes(buf, "gsr-stage");
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				}, buffer);
			} catch (GLib.Error e) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
		}
	}
}
