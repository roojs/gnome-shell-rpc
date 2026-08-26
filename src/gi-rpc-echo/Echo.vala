namespace GnomeShellRpc.GiRpcEcho
{
	/**
	 * Server handler for {@code GiRpcSmoke.ping}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * GnomeShellRpc.GiRpcEcho.Echo.rpc_register();
	 * OLLMrpc.Request.register(
	 *     "GiRpcSmoke",
	 *     new GnomeShellRpc.GiRpcEcho.Echo());
	 * }}}
	 */
	public class Echo : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"GiRpcSmoke", typeof(Echo),
				"ping", "s",
				null
			);
		}

		/**
		 * ''GiRpcSmoke.ping'' — echo the message.
		 *
		 * @param request inbound RPC
		 * @param msg client string
		 */
		public void ping(OLLMrpc.Request request, string msg)
		{
			GLib.print("got this call: ping msg=%s\n", msg);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("s", "echo:" + msg),
			});
		}
	}
}
