/**
 * Delivers {@link Meta.Window} Override RPC (plan 0.5.6 B3).
 *
 * Wire prefix ''Helper-Window''. Lease is the window.
 * {@link Meta.WindowForeachFunc} continue is the bool on
 * {@link OLLMrpc.Live.Hook.reply_args} after {@code RPC-Live-Callback.reply}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Window : GLib.Object
	{
		public static void register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Window", typeof(Window),
				"foreach_transient", "t",
				null
			);
			OLLMrpc.Request.register_live("Helper-Window",
				 new Window());
		}

		public void foreach_transient(
			OLLMrpc.Request request,
			uint64 callback_id
		) {
			var window = (Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				GLib.warning("unknown callback id");
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			window.foreach_transient((w) => {
				row.emit(OLLMrpc.args("t", row.connection.export(w)));
				if (row.reply_args.size < 1) {
					return false;
				}
				return row.reply_args.get(0).get_boolean();
			});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
