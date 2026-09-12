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
		 * Replies when {@code loaded} has fired (or on timeout). Does not
		 * nest a {@link GLib.MainLoop} — safe mid-{@link OLLMrpc.Live.Hook.emit}.
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
			request.connection.export(image);
			if (image.is_loaded()) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("o", image),
				});
				return;
			}
			/*
			 * Client stubs declare {@code loaded} but do not forward it.
			 * Hold the Request until Meta emits {@code loaded} (success or
			 * failure) or the timeout fires — no nested MainLoop.
			 */
			ulong hid = 0;
			uint tid = 0;
			hid = image.loaded.connect(() => {
				if (tid != 0) {
					GLib.Source.remove(tid);
					tid = 0;
				}
				image.disconnect(hid);
				if (!image.is_loaded()) {
					request.connection.reply_error(
						request,
						(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR,
						new GLib.IOError.FAILED(
							@"BackgroundImageCache.load failed uri=$(uri)")
					);
					return;
				}
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("o", image),
				});
			});
			tid = GLib.Timeout.add_seconds(3, () => {
				tid = 0;
				image.disconnect(hid);
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR,
					new GLib.IOError.TIMED_OUT(
						@"BackgroundImageCache.load timed out uri=$(uri)")
				);
				return GLib.Source.REMOVE;
			});
		}
	}
}
