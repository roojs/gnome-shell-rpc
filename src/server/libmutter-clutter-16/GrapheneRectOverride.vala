/**
 * {@link Graphene.Rect} as x, y, width, height.
 *
 * {@code Clutter.InputMethod.cursor-location-changed} otherwise writes
 * the raw rect.
 */
namespace Gsr.Server.Clutter
{
	public class GrapheneRectOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(Graphene.Rect); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return OLLMrpc.args("dddd", 0.0, 0.0, 0.0, 0.0);
			}
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
			return GLib.Value(typeof(Graphene.Rect));
		}
	}
}
