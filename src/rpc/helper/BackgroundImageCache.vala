/**
 * Delivers {@link Meta.BackgroundImageCache} Override RPC.
 *
 * Wire prefix ''Helper-BackgroundImageCache''. {@code GLib.File} is not
 * on the wire — client sends URI string (same pattern as
 * {@link Background.set_file}).
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class BackgroundImageCache : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-BackgroundImageCache", typeof(BackgroundImageCache),
				"load", "s",
				null
			);
			OLLMrpc.Request.register_live(
				"Helper-BackgroundImageCache", new BackgroundImageCache());
		}

		/**
		 * ''Helper-BackgroundImageCache.load'' — URI → compositor
		 * {@link Meta.BackgroundImageCache.load}.
		 *
		 * @param request inbound RPC (lease = cache)
		 * @param uri file URI, or empty
		 */
		public void load(OLLMrpc.Request request, string uri)
		{
			var cache = (Meta.BackgroundImageCache) request.connection.leases.get(
				(int) request.lease_id
			);
			/* Do not trust the JS caller — wire can send anything. */
			if (uri == "") {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.INVALID_ARGUMENT(
						"BackgroundImageCache.load requires a non-empty uri")
				);
				return;
			}
			var file = GLib.File.new_for_uri(uri);
			if (!file.query_exists()) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.NOT_FOUND(
						@"BackgroundImageCache.load missing uri=$(uri)")
				);
				return;
			}
			var image = cache.load(file);
			/*
			 * Client stubs declare {@code loaded} but do not forward it.
			 * Wait so {@code is_loaded()} is true before reply. Stock
			 * Meta emits {@code loaded} on success *or* failure; timeout
			 * means that signal never came — fail the RPC.
			 */
			if (!image.is_loaded()) {
				var loop = new GLib.MainLoop();
				var hid = image.loaded.connect(() => {
					loop.quit();
				});
				uint tid = 0;
				tid = GLib.Timeout.add_seconds(3, () => {
					tid = 0;
					loop.quit();
					return GLib.Source.REMOVE;
				});
				if (!image.is_loaded()) {
					loop.run();
				}
				if (tid != 0) {
					GLib.Source.remove(tid);
				}
				image.disconnect(hid);
			}
			if (!image.is_loaded()) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR,
					new GLib.IOError.TIMED_OUT(
						@"BackgroundImageCache.load timed out uri=$(uri)")
				);
				return;
			}
			request.connection.export(image);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", image),
			});
		}
	}
}
