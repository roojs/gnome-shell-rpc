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
				string msg = "";
				if (request.values.size > 0) {
					msg = request.values.get(0).get_string();
				} else {
					var p = (GiRpcSmoke.PingParams)request.param;
					msg = p.msg;
				}
				GLib.print("got this call: ping msg=%s\n", msg);
				var response = new OLLMrpc.Response() {
					id = request.id,
				};
				var reply = new GLib.Value(GLib.Type.STRING);
				reply.set_string("echo:" + msg);
				response.values.add(reply);
				request.reply(response);
			});
		}
	}
}
