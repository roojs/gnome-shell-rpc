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
		public Meta.Display display { get; private set; }

		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Bootstrap", typeof(Bootstrap));
			BootstrapParams.rpc_register();
		}

		public static Bootstrap bind(Meta.Display display)
		{
			var bootstrap = new Bootstrap();
			bootstrap.display = display;
			return bootstrap;
		}

		public signal void call_get_display(OLLMrpc.Request request);

		construct
		{
			this.call_get_display.connect((request) => {
				var handle = (uint64) request.connection.export(this.display);
				var lease_val = GLib.Value(GLib.Type.UINT64);
				lease_val.set_uint64(handle);
				var response = new OLLMrpc.Response() {
					id = request.id,
				};
				response.values.add(lease_val);
				request.reply(response);
			});
		}
	}
}
