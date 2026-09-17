/**
 * Delivers {@code St.ImageContent.set_data} — pixmap bytes on
 * {@link OLLMrpc.Request.buffer} (memfd / SCM_RIGHTS).
 *
 * Wire prefix {@code Helper-ImageContent}. Distro has no St-16.vapi for
 * mutter-rpc — same CCode pattern as {@link IconTheme}.
 *
 * Compositor Cogl context from {@link Clutter.get_default_backend};
 * client does not ship {@code Cogl.Context}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class ImageContent : GLib.Object
	{
		[CCode (cname = "st_image_content_new_with_preferred_size")]
		private static extern GLib.Object st_image_content_new_with_preferred_size(
			int width,
			int height
		);

		[CCode (cname = "st_image_content_set_data")]
		private static extern bool st_image_content_set_data(
			GLib.Object content,
			Cogl.Context cogl_context,
			uint8* data,
			Cogl.PixelFormat pixel_format,
			uint width,
			uint height,
			uint row_stride
		) throws GLib.Error;

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-ImageContent", typeof(ImageContent),
				"create", "ii",
				"set_data", "uuuux",
				null
			);
			OLLMrpc.Request.register_live(
				"Helper-ImageContent", new ImageContent());
		}

		/**
		 * {@code Helper-ImageContent.create} — stock
		 * {@code st_image_content_new_with_preferred_size}.
		 */
		public void create(OLLMrpc.Request request, int width, int height)
		{
			var peer = st_image_content_new_with_preferred_size(width, height);
			request.connection.export(peer);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", peer),
			});
		}

		/**
		 * {@code Helper-ImageContent.set_data} — read pixels from
		 * {@link OLLMrpc.Request.buffer}, stock libst upload.
		 *
		 * @param request inbound RPC (lease = ImageContent)
		 * @param pixel_format {@link Cogl.PixelFormat} bits
		 * @param width image width
		 * @param height image height
		 * @param row_stride bytes per row
		 * @param nbytes pixel payload size
		 */
		public void set_data(
			OLLMrpc.Request request,
			uint pixel_format,
			uint width,
			uint height,
			uint row_stride,
			int64 nbytes
		) {
			var content = (GLib.Object) request.connection.leases.get(
				(int) request.lease_id);
			var got = request.buffer != null ? request.buffer.fd : -1;
			if (content == null || got < 0 || nbytes < 0) {
				request.connection.reply_error(request,				(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var backend = Clutter.get_default_backend();
			var cogl = backend.get_cogl_context();
			var buf = new uint8[nbytes];
			Posix.lseek(got, 0, Posix.SEEK_SET);
			var nread = 0;
			while (nread < nbytes) {
				var n = Posix.read(got, (void*) &buf[nread], (size_t) (nbytes - nread));
				if (n <= 0) {
					break;
				}
				nread += (int) n;
			}
			if (nread != nbytes) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
			var ok = false;
			try {
				ok = st_image_content_set_data(content, cogl, buf,
					(Cogl.PixelFormat) pixel_format, width, height, row_stride);
			} catch (GLib.Error e) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e);
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
			});
		}
	}
}
