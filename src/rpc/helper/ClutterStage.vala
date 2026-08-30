/**
 * Clutter Stage / PaintContext Helpers for C ABI gaps (libshell link).
 *
 * Wire prefixes ''Clutter-Stage'' / ''Clutter-PaintContext''. Live GObject
 * returns use uint64 lease in {@link OLLMrpc.Response.args} (not retval).
 * {@code get_stage_view} / {@code get_view_at} are not in the mutter VAPI
 * ({@code introspectable=0}) — call stock C directly via {@code extern}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class ClutterPaintContext : GLib.Object
	{
		[CCode (cname = "clutter_paint_context_get_stage_view",
			cheader_filename = "clutter/clutter.h")]
		private static extern Clutter.StageView? clutter_paint_context_get_stage_view(
			void* paint_context
		);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Clutter-PaintContext", typeof(ClutterPaintContext),
				"get_stage_view", "",
				null
			);
			OLLMrpc.Request.register_live("Clutter-PaintContext",
				new ClutterPaintContext());
		}

		/**
		 * ''Clutter-PaintContext.get_stage_view'' — lease id of the view.
		 *
		 * @param request inbound RPC; lease is the paint context
		 */
		public void get_stage_view(OLLMrpc.Request request)
		{
			var paint_context = request.connection.leases.get(
				(int) request.lease_id);
			var view = clutter_paint_context_get_stage_view(paint_context);
			uint64 handle = 0;
			if (view != null) {
				handle = (uint64) request.connection.export(view);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}
	}

	public class ClutterStage : GLib.Object
	{
		[CCode (cname = "clutter_stage_get_view_at",
			cheader_filename = "clutter/clutter.h")]
		private static extern Clutter.StageView? clutter_stage_get_view_at(
			Clutter.Stage stage,
			float x,
			float y
		);

		public static void rpc_register()
		{
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
		 * ''Clutter-Stage.get_view_at'' — lease id of the view.
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
			uint64 handle = 0;
			if (view != null) {
				handle = (uint64) request.connection.export(view);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		/**
		 * ''Clutter-Stage.paint_to_buffer'' — pixel {@link GLib.Bytes} in args[0].
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
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("ay", new GLib.Bytes(buf)),
			});
		}
	}
}
