/**
 * Delivers {@link Meta.SelectionSourceMemory} Override RPC (plan 0.5.8).
 *
 * Wire prefix ''Helper-SelectionSourceMemory''. Constructor takes mimetype +
 * {@link GLib.Bytes} payload; reply exports the compositor source.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class SelectionSourceMemory : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-SelectionSourceMemory", typeof(SelectionSourceMemory),
				"create", "say",
				null
			);
			OLLMrpc.Request.register_live("Helper-SelectionSourceMemory",
				new SelectionSourceMemory());
		}

		public void create(
			OLLMrpc.Request request,
			string mimetype,
			GLib.Bytes content
		) {
			Meta.SelectionSource? source = null;
			try {
				source = new Meta.SelectionSourceMemory(mimetype, content);
			} catch (GLib.Error e) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e);
				return;
			}
			request.connection.export(source);
			var response = new OLLMrpc.Response() {
				id = request.id,
			};
			response.result.add(source);
			request.reply(response);
		}
	}
}
