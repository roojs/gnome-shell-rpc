/**
 * Delivers {@link Meta.Context} Override RPC (plan 0.5.7 C3).
 *
 * Wire prefix ''Meta-Helper-Context''.
 */
namespace GnomeShellRpc.Rpc.MetaHelper
{
	public class ContextHelper : GLib.Object
	{
		public static void register()
		{
			OLLMrpc.Request.add_class(
				"Meta-Helper-Context", typeof(ContextHelper),
				"terminate_with_error", "sis",
				null
			);
			OLLMrpc.Request.register_live(
				"Meta-Helper-Context",
				new ContextHelper()
			);
		}

		public void terminate_with_error(
			OLLMrpc.Request request,
			string domain,
			int code,
			string message
		)
		{
			var context = (Meta.Context) request.connection.leases.get((int) request.lease_id);
			var error = new GLib.Error.literal(
				GLib.Quark.from_string(domain),
				code,
				message
			);
			context.terminate_with_error(error);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
