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
		}

		public int protocol { get; set; default = 1; }
		public string server { get; set; default = "gnome-shell-rpc"; }
		public bool ready { get; set; default = true; }

		public signal void call_hello(OLLMrpc.Request request);

		construct
		{
			this.call_hello.connect((request) => {
				var protocol = 0;
				if (request.args.size > 0) {
					protocol = request.args.get(0).get_int();
				}
				if (protocol > 0) {
					this.protocol = protocol;
				}
				var response = new OLLMrpc.Response() {
					id = request.id,
				};
				response.result.add(this);
				request.reply(response);
			});
		}
	}
}
