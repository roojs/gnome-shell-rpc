/**
 * Client-side {@link Clutter.Content} built from RPC paint pixels (0.5.5 D).
 *
 * Holds RGBA from the Helper memfd. Preferred size is the paint size.
 * {@link paint_content} is a no-op until a local Cogl upload path exists.
 */
namespace GnomeShellRpc.GiStub
{
	public class PaintedContent : GLib.Object, Clutter.Content
	{
		public int pixel_width { get; construct; }
		public int pixel_height { get; construct; }
		public int stride { get; construct; }
		public uint8[] pixels { get; owned set; }

		public PaintedContent(
			int width,
			int height,
			int stride,
			owned uint8[] pixels
		) {
			Object(
				pixel_width: width,
				pixel_height: height,
				stride: stride
			);
			this.pixels = (owned) pixels;
		}

		public bool get_preferred_size(out float width, out float height)
		{
			width = (float) this.pixel_width;
			height = (float) this.pixel_height;
			return this.pixel_width > 0 && this.pixel_height > 0;
		}

		public void invalidate()
		{
		}

		public void invalidate_size()
		{
		}

		public void paint_content(
			Clutter.Actor actor,
			Clutter.PaintNode node,
			Clutter.PaintContext paint_context
		) {
		}
	}
}
