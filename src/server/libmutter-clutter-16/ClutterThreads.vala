/**
 * Delivers {@code global::Clutter.threads_add_repaint_func} Override RPC.
 *
 * Wire prefix ''Gsr-Clutter-Threads''. No lease — namespace function. Stock
 * registration is {@link global::Clutter.Threads.add_repaint_func}; continue bool is
 * on {@link OLLMrpc.Live.Hook.reply_args} after {@code RPC-Live-Callback.reply}.
 */
namespace Gsr.Server.Clutter
{
	public class ClutterThreads : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Clutter-Threads", typeof(ClutterThreads),
				"threads_add_repaint_func", "ut",
				null
			);
			OLLMrpc.Request.register_live("Gsr-Clutter-Threads",
				new ClutterThreads());
		}

		public void threads_add_repaint_func(
			OLLMrpc.Request request,
			uint flags,
			uint64 callback_id
		) {
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				GLib.warning("unknown callback id");
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("u", (uint) 0),
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			var handle = global::Clutter.Threads.add_repaint_func(
				(global::Clutter.RepaintFlags) flags,
				() => {
					row.emit(OLLMrpc.args(""));
					if (row.reply_args.size < 1) {
						return false;
					}
					return row.reply_args.get(0).get_boolean();
				});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("u", handle),
			});
		}
	}
}
