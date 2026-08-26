namespace GnomeShellRpc.GiRpcEcho
{
	/**
	 * Server handler for {@code GiRpcSmoke.ping}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * OLLMrpc.Request.register(
	 *     "GiRpcSmoke",
	 *     new GnomeShellRpc.GiRpcEcho.Echo());
	 * }}}
	 */
	public class Echo : GLib.Object
	{
		public signal void call_ping(OLLMrpc.Request request);

		construct
		{
			this.call_ping.connect((request) => {
				var msg = "";
				if (request.args.size > 0) {
					msg = request.args.get(0).get_string();
				}
				GLib.print("got this call: ping msg=%s\n", msg);
				var response = new OLLMrpc.Response() {
					id = request.id,
					args = OLLMrpc.args("s", "echo:" + msg),
				};
				request.reply(response);
			});
		}
	}
}
