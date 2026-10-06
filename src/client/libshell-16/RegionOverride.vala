/**
 * Client rebuild of an {@link Mtk.Region} from a rectangle count and
 * each rectangle's x, y, width, height.
 */
namespace Shell
{
	internal class RegionOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(Mtk.Region); }
		}

		[CCode (cname = "mtk_rectangle_new", cheader_filename = "mtk/mtk.h")]
		private static extern Mtk.Rectangle* mtk_rectangle_new(
			int x, int y, int width, int height);

		[CCode (cname = "mtk_rectangle_free", cheader_filename = "mtk/mtk.h")]
		private static extern void mtk_rectangle_free(Mtk.Rectangle* rect);

		[CCode (cname = "mtk_region_union_rectangle", cheader_filename = "mtk/mtk.h")]
		private static extern void mtk_region_union_rectangle(
			Mtk.Region region, Mtk.Rectangle* rect);

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			var fields = new Gee.ArrayList<GLib.Value?>();
			fields.add(OLLMrpc.val("i", 0));
			return fields;
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			var n = fields.get(index).get_int();
			consumed = 1 + n * 4;
			var region = Mtk.Region.create();
			for (var i = 0; i < n; i++) {
				var at = index + 1 + i * 4;
				var rect = mtk_rectangle_new(
					fields.get(at).get_int(), fields.get(at + 1).get_int(),
					fields.get(at + 2).get_int(), fields.get(at + 3).get_int());
				mtk_region_union_rectangle(region, rect);
				mtk_rectangle_free(rect);
			}
			var v = GLib.Value(typeof(Mtk.Region));
			v.set_boxed(region);
			return v;
		}

		internal static void register()
		{
			OLLMrpc.Bin.TypeOverride.register(new RegionOverride());
		}
	}
}
