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
	 *     new GnomeShellRpc.GiRpcEcho.Echo(),
	 *     typeof(GiRpcSmoke.PingParams));
	 * }}}
	 */
	public class Echo : GLib.Object
	{
		public signal void call_ping(OLLMrpc.Request request);

		construct
		{
			this.call_ping.connect((request) => {
				var p = (GiRpcSmoke.PingParams)request.param;
				GLib.print("got this call: ping msg=%s\n", p.msg);
				var response = new OLLMrpc.Response() {
					id = request.id,
				};
				response.result.add(new GiRpcSmoke.PingResult() {
					reply = "echo:" + p.msg,
				});
				request.reply(response);
			});
		}
	}
}
