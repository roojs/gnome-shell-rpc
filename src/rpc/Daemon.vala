namespace GnomeShellRpc.Rpc
{
	/**
	 * Server {@code RPC-Daemon.hello}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * OLLMrpc.Request.register(
	 *     "RPC-Daemon",
	 *     new GnomeShellRpc.Rpc.Daemon());
	 * }}}
	 */
	public class Daemon : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Daemon", typeof(Daemon));
			OLLMrpc.Request.add_class(
				"RPC-Daemon", typeof(Daemon),
				"hello", "is",
				null
			);
		}

		public int protocol { get; set; default = 1; }
		public string server { get; set; default = "gnome-shell-rpc"; }
		public bool ready { get; set; default = true; }

		public void hello(OLLMrpc.Request request, int protocol, string client)
		{
			if (protocol > 0) {
				this.protocol = protocol;
			}
			var response = new OLLMrpc.Response() {
				id = request.id,
			};
			response.result.add(this);
			request.reply(response);
		}
	}
}
