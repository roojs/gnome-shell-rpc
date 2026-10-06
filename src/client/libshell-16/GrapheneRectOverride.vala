/**
 * Client rebuild of a {@link Graphene.Rect} from x, y, width, height.
 */
namespace Shell
{
	internal class GrapheneRectOverride : OLLMrpc.Bin.TypeOverride
	{
		[CCode (cname = "graphene_rect_init", cheader_filename = "graphene.h")]
		private static extern unowned Graphene.Rect* graphene_rect_init(
			Graphene.Rect* rect, float x, float y, float width, float height);

		public override GLib.Type override_type {
			get { return typeof(Graphene.Rect); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			unowned var rect = (Graphene.Rect*) src.get_boxed();
			return OLLMrpc.args("dddd",
				(double) rect.origin.x, (double) rect.origin.y,
				(double) rect.size.width, (double) rect.size.height);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 4;
			var rect = (Graphene.Rect*) GLib.malloc0(sizeof(Graphene.Rect));
			graphene_rect_init(rect,
				(float) fields.get(index).get_double(),
				(float) fields.get(index + 1).get_double(),
				(float) fields.get(index + 2).get_double(),
				(float) fields.get(index + 3).get_double());
			var v = GLib.Value(typeof(Graphene.Rect));
			v.take_boxed(rect);
			return v;
		}

		internal static void register()
		{
			OLLMrpc.Bin.TypeOverride.register(new GrapheneRectOverride());
		}
	}
}
