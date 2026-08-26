namespace GnomeShellRpc.Rpc
{
	/**
	 * Bootstrap RPC — export compositor {@link Meta.Display} lease to client.
	 *
	 * Out-of-process stand-in until {@code Meta.get_display()} is a real
	 * constructor RPC. POC for 0.5.3 partial Clutter relay.
	 */
	public class Bootstrap : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public Meta.Display meta_display { get; private set; }

		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Bootstrap", typeof(Bootstrap));
			OLLMrpc.Request.add_class(
				"RPC-Bootstrap", typeof(Bootstrap),
				"get_display", "",
				null
			);
		}

		public static Bootstrap bind(Meta.Display display)
		{
			var bootstrap = new Bootstrap();
			bootstrap.meta_display = display;
			return bootstrap;
		}

		public void get_display(OLLMrpc.Request request)
		{
			var handle = (uint64) request.connection.export(this.meta_display);
			var response = new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			};
			request.reply(response);
		}
	}
}
