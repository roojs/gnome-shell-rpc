/**
 * Owned {@code Shell.Screenshot} — load-time promisify surface (0.7.7 T-037).
 *
 * Capture uses {@code Clutter-Stage.paint_to_buffer} → {@link PaintedContent}.
 */
namespace Shell
{
	public class Screenshot : GLib.Object
	{
		static void stage_pixels(
			out int width,
			out int height,
			out int stride,
			out uint8[] pixels
		) throws GLib.Error
		{
			var stage = Global.get().stage;
			float w, h;
			((Clutter.Actor) stage).get_size(out w, out h);
			width = (int) Math.ceilf(w);
			height = (int) Math.ceilf(h);
			if (width < 1) {
				width = 1;
			}
			if (height < 1) {
				height = 1;
			}
			stride = width * 4;
			pixels = new uint8[stride * height];
			Mtk.Rectangle rect = { 0, 0, width, height };
			GnomeShellRpc.GiStub.ClutterStageAbi.paint_to_buffer(
				stage, rect, 1f, pixels, stride,
				Cogl.PixelFormat.RGBA_8888, Clutter.PaintFlag.none);
		}

		static Gdk.Pixbuf pixbuf_from_rgba(
			int width,
			int height,
			int stride,
			uint8[] pixels
		) throws GLib.Error {
			var pb = new Gdk.Pixbuf.from_data(
				pixels, Gdk.Colorspace.RGB, true, 8,
				width, height, stride, null);
			return pb.copy();
		}

		public async bool pick_color(int x, int y, out Cogl.Color color) throws GLib.Error
		{
			int width, height, stride;
			uint8[] pixels;
			stage_pixels(out width, out height, out stride, out pixels);
			if (x < 0 || y < 0 || x >= width || y >= height) {
				throw new GLib.IOError.INVALID_ARGUMENT(
					"Shell.Screenshot.pick_color: out of range");
			}
			var i = y * stride + x * 4;
			color = Cogl.Color.from_4f(
				pixels[i] / 255f, pixels[i + 1] / 255f,
				pixels[i + 2] / 255f, pixels[i + 3] / 255f);
			return true;
		}

		public async bool screenshot(
			bool include_cursor,
			GLib.OutputStream stream,
			out Mtk.Rectangle area
		) throws GLib.Error {
			int width, height, stride;
			uint8[] pixels;
			stage_pixels(out width, out height, out stride, out pixels);
			area = { 0, 0, width, height };
			var pb = pixbuf_from_rgba(width, height, stride, pixels);
			pb.save_to_stream(stream, "png", null);
			return true;
		}

		public async bool screenshot_area(
			int x,
			int y,
			int width,
			int height,
			GLib.OutputStream stream,
			out Mtk.Rectangle area
		) throws GLib.Error
		{
			int sw, sh, stride;
			uint8[] pixels;
			stage_pixels(out sw, out sh, out stride, out pixels);
			if (x < 0 || y < 0 || width < 1 || height < 1 || x + width > sw || y + height > sh) {
				throw new GLib.IOError.INVALID_ARGUMENT(
					"Shell.Screenshot.screenshot_area: out of range");
			}
			area = { x, y, width, height };
			var cropped = new uint8[width * 4 * height];
			for (var row = 0; row < height; row++) {
				var src = (y + row) * stride + x * 4;
				var dst = row * width * 4;
				for (var col = 0; col < width * 4; col++) {
					cropped[dst + col] = pixels[src + col];
				}
			}
			var pb = pixbuf_from_rgba(width, height, width * 4, cropped);
			pb.save_to_stream(stream, "png", null);
			return true;
		}

		public async bool screenshot_window(
			bool include_frame,
			bool include_cursor,
			GLib.OutputStream stream,
			out Mtk.Rectangle area
		) throws GLib.Error {
			/* Nested: no focused-window grab yet — full stage. */
			return yield this.screenshot(include_cursor, stream, out area);
		}

		public async Clutter.Content screenshot_stage_to_content(
			out float scale,
			out Clutter.Content? cursor_content,
			out Graphene.Point cursor_point,
			out float cursor_scale
		) throws GLib.Error {
			int width, height, stride;
			uint8[] pixels;
			stage_pixels(out width, out height, out stride, out pixels);
			scale = 1f;
			cursor_content = null;
			cursor_point = Graphene.Point();
			cursor_point.init(0f, 0f);
			cursor_scale = 1f;
			return new GnomeShellRpc.GiStub.PaintedContent(
				width, height, stride, (owned) pixels);
		}

		public static async Gdk.Pixbuf composite_to_stream(
			Cogl.Texture texture,
			int x,
			int y,
			int width,
			int height,
			float scale,
			Cogl.Texture? cursor,
			int cursor_x,
			int cursor_y,
			float cursor_scale,
			GLib.OutputStream stream
		) throws GLib.Error {
			/* Client stubs have no Cogl texture download; composite from stage. */
			int sw, sh, stride;
			uint8[] pixels;
			stage_pixels(out sw, out sh, out stride, out pixels);
			int rw = width, rh = height;
			if (rw < 1) {
				rw = sw;
			}
			if (rh < 1) {
				rh = sh;
			}
			if (x < 0) {
				x = 0;
			}
			if (y < 0) {
				y = 0;
			}
			if (x + rw > sw) {
				rw = sw - x;
			}
			if (y + rh > sh) {
				rh = sh - y;
			}
			var cropped = new uint8[rw * 4 * rh];
			for (var row = 0; row < rh; row++) {
				var src = (y + row) * stride + x * 4;
				var dst = row * rw * 4;
				for (var col = 0; col < rw * 4; col++) {
					cropped[dst + col] = pixels[src + col];
				}
			}
			var pb = pixbuf_from_rgba(rw, rh, rw * 4, cropped);
			pb.save_to_stream(stream, "png", null);
			return pb;
		}
	}
}
