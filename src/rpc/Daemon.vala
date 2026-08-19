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
	 *     new GnomeShellRpc.Rpc.Daemon(),
	 *     typeof(GnomeShellRpc.Rpc.DaemonParams));
	 * }}}
	 */
	public class Daemon : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Daemon", typeof(Daemon));
			DaemonParams.rpc_register();
		}

		public int protocol { get; set; default = 1; }
		public string server { get; set; default = "gnome-shell-rpc"; }
		public bool ready { get; set; default = true; }

		public signal void call_hello(OLLMrpc.Request request);

		construct
		{
			this.call_hello.connect((request) => {
				var p = (DaemonParams)request.param;
				if (p.protocol > 0) {
					this.protocol = p.protocol;
				}
				var result = new Gee.ArrayList<GLib.Object>();
				result.add(this);
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					result = result,
				});
			});
		}
	}
}
