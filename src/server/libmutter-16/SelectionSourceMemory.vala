/**
 * Delivers {@link global::Meta.SelectionSourceMemory} Override RPC (plan 0.5.8).
 *
 * Wire prefix ''Gsr-Mutter-SelectionSourceMemory''. Constructor takes mimetype +
 * {@link GLib.Bytes} payload; reply exports the compositor source.
 */
namespace Gsr.Server.Meta
{
	public class SelectionSourceMemory : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Mutter-SelectionSourceMemory", typeof(SelectionSourceMemory),
				"create", "say",
				null
			);
			OLLMrpc.Request.register_live("Gsr-Mutter-SelectionSourceMemory",
				new SelectionSourceMemory());
		}

		public void create(
			OLLMrpc.Request request,
			string mimetype,
			GLib.Bytes content
		) {
			global::Meta.SelectionSource? source = null;
			try {
				source = new global::Meta.SelectionSourceMemory(mimetype, content);
			} catch (GLib.Error e) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e);
				return;
			}
			request.connection.export(source);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", source),
			});
		}
	}
}
