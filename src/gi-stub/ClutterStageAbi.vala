/**
 * Client exports for Clutter Stage / PaintContext symbols GIR does not emit
 * ({@code introspectable=0} or data-array gap). Stock {@code clutter_*} cnames;
 * bodies RPC (same idea as {@link ShaderEffectUniform}, without a C trampoline).
 */
namespace GnomeShellRpc.GiStub
{
	public class ClutterStageAbi : GLib.Object
	{
		/**
		 * ''Clutter-PaintContext.get_stage_view'' — lease in args[0].
		 *
		 * @param paint_context leased stub PaintContext
		 * @return StageView stub with {@link Clutter.StageView.rpc_lid}, or null
		 */
		[CCode (cname = "clutter_paint_context_get_stage_view")]
		public static Clutter.StageView? get_stage_view(
			Clutter.PaintContext paint_context
		) {
			try {
				var response = Runtime.call_values(
					"Clutter-PaintContext.get_stage_view", paint_context);
				if (response.args.size == 0) {
					return null;
				}
				var handle = response.args.get(0).get_uint64();
				if (handle == 0) {
					return null;
				}
				var view = new Clutter.StageView();
				view.rpc_lid = handle;
				return view;
			} catch (GLib.Error e) {
				GLib.warning("get_stage_view: %s", e.message);
				return null;
			}
		}

		/**
		 * ''Clutter-Stage.get_view_at'' — lease in args[0].
		 *
		 * @param stage leased stub Stage
		 * @param x stage X
		 * @param y stage Y
		 * @return StageView stub with {@link Clutter.StageView.rpc_lid}, or null
		 */
		[CCode (cname = "clutter_stage_get_view_at")]
		public static Clutter.StageView? get_view_at(
			Clutter.Stage stage,
			float x,
			float y
		) {
			try {
				var response = Runtime.call_values(
					"Clutter-Stage.get_view_at", stage,
					OLLMrpc.args("ff", x, y));
				if (response.args.size == 0) {
					return null;
				}
				var handle = response.args.get(0).get_uint64();
				if (handle == 0) {
					return null;
				}
				var view = new Clutter.StageView();
				view.rpc_lid = handle;
				return view;
			} catch (GLib.Error e) {
				GLib.warning("get_view_at: %s", e.message);
				return null;
			}
		}

		/**
		 * ''Clutter-Stage.paint_to_buffer'' — pixels as {@link GLib.Bytes} in args[0].
		 *
		 * @param stage leased stub Stage
		 * @param rect capture rectangle
		 * @param scale capture scale
		 * @param data caller buffer to fill
		 * @param stride row stride
		 * @param format Cogl pixel format
		 * @param paint_flags Clutter paint flags
		 * @return true if pixels were written
		 * @throws GLib.Error remote or RPC failure
		 */
		[CCode (cname = "clutter_stage_paint_to_buffer")]
		public static bool paint_to_buffer(
			Clutter.Stage stage,
			Mtk.Rectangle rect,
			float scale,
			[CCode (array_length = false)] uint8[] data,
			int stride,
			Cogl.PixelFormat format,
			Clutter.PaintFlag paint_flags
		) throws GLib.Error {
			var image_height = (int) Math.ceilf(rect.height * scale);
			if (image_height < 1) {
				image_height = 1;
			}
			var n_bytes = stride * image_height;
			var response = Runtime.call_values(
				"Clutter-Stage.paint_to_buffer", stage,
				OLLMrpc.args(
					"iiiifiiuu",
					rect.x, rect.y, rect.width, rect.height, scale,
					n_bytes, stride, (uint) format, (uint) paint_flags
				));
			if (response.args.size == 0) {
				throw new GLib.IOError.FAILED("paint_to_buffer: empty reply");
			}
			var bytes = (GLib.Bytes) response.args.get(0).get_boxed();
			var pixels = bytes.get_data();
			var n = int.min(n_bytes, pixels.length);
			GLib.Memory.copy(data, pixels, n);
			return true;
		}
	}
}
