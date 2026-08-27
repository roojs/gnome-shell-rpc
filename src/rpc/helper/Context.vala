/**
 * Delivers {@link Meta.Context} Override RPC (plan 0.5.7 C3).
 *
 * Wire prefix ''Helper-Context''.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Context : GLib.Object
	{
		public static void register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Context", typeof(Context),
				"terminate_with_error", "sis",
				null
			);
			OLLMrpc.Request.register_live("Helper-Context", new Context());
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
