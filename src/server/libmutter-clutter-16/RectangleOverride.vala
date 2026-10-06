/**
 * {@link Mtk.Rectangle} as x, y, width, height.
 *
 * {@code size-change}, {@code show-tile-preview}, {@code show-window-menu},
 * and {@code show-resize-popup} otherwise write the raw box.
 */
namespace Gsr.Server.Clutter
{
	public class RectangleOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(Mtk.Rectangle); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return OLLMrpc.args("iiii", 0, 0, 0, 0);
			}
			unowned var rect = (Mtk.Rectangle*) src.get_boxed();
			return OLLMrpc.args("iiii", rect.x, rect.y, rect.width, rect.height);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 4;
			return GLib.Value(typeof(Mtk.Rectangle));
		}
	}
}
