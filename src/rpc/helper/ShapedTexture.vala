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

			string path;
			GLib.IOStream iostream;
			try {
				var file = GLib.File.new_tmp("gsr-shape-XXXXXX", out iostream);
				path = file.get_path();
				size_t written;
				iostream.output_stream.write_all(pixels, out written);
				iostream.close();
			} catch (GLib.Error e) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e);
				return;
			}
			var fd = Posix.open(path, Posix.O_RDONLY);
			GLib.FileUtils.unlink(path);
			if (fd < 0) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("iii", img.get_width(), height, stride),
			}, new OLLMrpc.Live.Buffer(fd));
		}
	}
}
