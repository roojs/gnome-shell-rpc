/**
 * Delivers {@link Meta.Context} Override RPC (plan 0.5.7 C3).
 *
 * Wire prefix ''Helper-Context''; also ''Meta-Context.terminate'' (noop ack
 * on live compositor — client smokes must not tear down mutter-rpc).
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Context : GLib.Object
	{
		private StartupFrameGate gate;

		public Context(StartupFrameGate gate)
		{
			this.gate = gate;
		}

		public static void rpc_register(StartupFrameGate gate)
		{
			var helper = new Context(gate);
			OLLMrpc.Request.add_class(
				"Helper-Context", typeof(Context),
				"terminate_with_error", "sis",
				null
			);
			OLLMrpc.Request.register_live("Helper-Context", helper);

			OLLMrpc.Request.add_class(
				"Meta-Context", typeof(Context),
				"terminate", "",
				"notify_ready", "",
				null
			);
			OLLMrpc.Request.register_live("Meta-Context", helper);
		}

		/**
		 * Release the startup frame gate, then call stock notify_ready.
		 *
		 * @param request notify request from the shell connection
		 */
		public void notify_ready(OLLMrpc.Request request)
		{
			if (!this.gate.release((GnomeShellRpc.Rpc.Connection) request.connection)) {
				request.connection.reply_error(
					request, (int) OLLMrpc.RpcErrorCode.INVALID_REQUEST);
				return;
			}

			((Meta.Context) request.connection.leases.get(
				(int) request.lease_id)).notify_ready();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void terminate_with_error(
			OLLMrpc.Request request,
			string domain,
			int code,
			string message
		) {
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

		/**
		 * ''Meta-Context.terminate'' — smoke done; void ack only on live server.
		 */
		public void terminate(OLLMrpc.Request request)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
