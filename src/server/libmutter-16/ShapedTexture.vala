/**
 * Delivers {@link Meta.ShapedTexture} Override RPC (plan 0.5.8).
 *
 * Wire prefix ''Helper-ShapedTexture''. Lease is the shaped texture.
 * {@link get_image} replies with ARGB32 dims on {@link OLLMrpc.Response.args}
 * and the pixel memfd on {@link OLLMrpc.Request.reply}'s buffer.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class ShapedTexture : GLib.Object
	{
		[CCode (cname = "memfd_create", cheader_filename = "sys/mman.h")]
		private static extern int memfd_create(string name, uint flags);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-ShapedTexture", typeof(ShapedTexture),
				"get_image", "biiii",
				null
			);
			OLLMrpc.Request.register_live("Helper-ShapedTexture",
				new ShapedTexture());
		}

		public void get_image(
			OLLMrpc.Request request,
			bool has_clip,
			int clip_x,
			int clip_y,
			int clip_width,
			int clip_height
		) {
			var stex = (Meta.ShapedTexture) request.connection.leases.get(
				(int) request.lease_id);
			Mtk.Rectangle? clip = null;
			if (has_clip) {
				clip = { clip_x, clip_y, clip_width, clip_height };
			}
			var surface = stex.get_image(clip);
			ShapedTexture.reply_cairo_image(request, surface);
		}

		private static void reply_cairo_image(
			OLLMrpc.Request request,
			Cairo.Surface? surface
		) {
			if (surface == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			if (surface.get_type() != Cairo.SurfaceType.IMAGE) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var img = (Cairo.ImageSurface) surface;
			img.flush();
			var height = img.get_height();
			var stride = img.get_stride();
			var nbytes = stride * height;
			var pixels = new uint8[nbytes];
			GLib.Memory.copy(pixels, img.get_data(), (size_t) nbytes);

			var fd = memfd_create("gsr-shape", 1);
			if (fd < 0 || Posix.write(fd, pixels, nbytes) != nbytes) {
				if (fd >= 0) {
					Posix.close(fd);
				}
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			Posix.lseek(fd, 0, Posix.SEEK_SET);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("iii", img.get_width(), height, stride),
			}, new OLLMrpc.Live.Buffer(fd));
		}
	}
}
