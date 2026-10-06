/**
 * Client rebuild of an {@link Mtk.Rectangle} from x, y, width, height.
 */
namespace Shell
{
	internal class RectangleOverride : OLLMrpc.Bin.TypeOverride
	{
		[CCode (cname = "mtk_rectangle_new", cheader_filename = "mtk/mtk.h")]
		private static extern Mtk.Rectangle* mtk_rectangle_new(
			int x, int y, int width, int height);

		public override GLib.Type override_type {
			get { return typeof(Mtk.Rectangle); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			unowned var rect = (Mtk.Rectangle*) src.get_boxed();
			return OLLMrpc.args("iiii", rect.x, rect.y, rect.width, rect.height);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 4;
			var rect = mtk_rectangle_new(
				fields.get(index).get_int(), fields.get(index + 1).get_int(),
				fields.get(index + 2).get_int(), fields.get(index + 3).get_int());
			var v = GLib.Value(typeof(Mtk.Rectangle));
			v.take_boxed(rect);
			return v;
		}

		internal static void register()
		{
			OLLMrpc.Bin.TypeOverride.register(new RectangleOverride());
		}
	}
}
