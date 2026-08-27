/**
 * Delivers {@link Meta.WindowActor} Override RPC (plan 0.5.5 D).
 *
 * Wire prefix ''Helper-WindowActor''. Lease is the window actor.
 * {@link paint_to_content} replies with RGBA dims on {@link OLLMrpc.Response.args}
 * and the pixel memfd on {@link OLLMrpc.Request.reply}'s buffer.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class WindowActor : GLib.Object
	{
		public static void register()
		{
			OLLMrpc.Request.add_class(
				"Helper-WindowActor", typeof(WindowActor),
				"paint_to_content", "biiii",
				null
			);
			OLLMrpc.Request.register_live("Helper-WindowActor",
				new WindowActor());
		}

		public void paint_to_content(
			OLLMrpc.Request request,
			bool has_clip,
			int clip_x,
			int clip_y,
			int clip_width,
			int clip_height
		) {
			var actor = (Meta.WindowActor) request.connection.leases.get(
				(int) request.lease_id);
			Clutter.Content? content = null;
			try {
				if (has_clip) {
					Mtk.Rectangle clip = {};
					clip.x = clip_x;
					clip.y = clip_y;
					clip.width = clip_width;
					clip.height = clip_height;
					content = actor.paint_to_content(clip);
				} else {
					content = actor.paint_to_content(null);
				}
			} catch (GLib.Error e) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e);
				return;
			}
			if (content == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var texture_content = content as Clutter.TextureContent;
			if (texture_content == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var texture = texture_content.get_texture();
			var width = texture.get_width();
			var height = texture.get_height();
			var stride = width * 4;
			var nbytes = stride * height;
			var pixels = new uint8[nbytes];
			texture.get_data(Cogl.PixelFormat.RGBA_8888, stride, pixels);

			string path;
			GLib.IOStream iostream;
			try {
				var file = GLib.File.new_tmp("gsr-paint-XXXXXX", out iostream);
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
				args = OLLMrpc.args("iii", width, height, stride),
			}, new OLLMrpc.Live.Buffer(fd));
		}
	}
}
