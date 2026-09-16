/**
 * Clutter-PaintContext Helper for C ABI gaps (libshell link).
 *
 * Wire prefix ''Clutter-PaintContext''. Live GObject returns use uint64
 * lease in {@link OLLMrpc.Response.args} (not retval).
 * {@code get_stage_view} is not in the mutter VAPI
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
}
