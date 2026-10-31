/**
 * {@link Mtk.Region} as a count, then each rectangle's x, y, width, height.
 *
 * {@code Clutter.Stage.paint-view} carries the redraw clip as this type.
 */
namespace Gsr.Server.Clutter
{
	public class RegionOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(Mtk.Region); }
		}

		[CCode (cname = "mtk_region_get_box", cheader_filename = "mtk/mtk.h")]
		private static extern void mtk_region_get_box(Mtk.Region region, int nth,
			out int x1, out int y1, out int x2, out int y2);

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			var fields = new Gee.ArrayList<GLib.Value?>();
			if (src.get_boxed() == null) {
				fields.add(OLLMrpc.val("i", 0));
				return fields;
			}
			unowned var region = (Mtk.Region) src.get_boxed();
			var n = region.num_rectangles();
			fields.add(OLLMrpc.val("i", n));
			for (var i = 0; i < n; i++) {
				int x1, y1, x2, y2;
				mtk_region_get_box(region, i, out x1, out y1, out x2, out y2);
				fields.add(OLLMrpc.val("i", x1));
				fields.add(OLLMrpc.val("i", y1));
				fields.add(OLLMrpc.val("i", x2 - x1));
				fields.add(OLLMrpc.val("i", y2 - y1));
			}
			return fields;
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			var n = fields.get(index).get_int();
			consumed = 1 + n * 4;
			return GLib.Value(typeof(Mtk.Region));
		}
	}
}
