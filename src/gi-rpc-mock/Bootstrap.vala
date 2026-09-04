namespace GnomeShellRpc.GiRpcMock
{
	/**
	 * Ffi {@code RPC-Bootstrap.get_display} — exports a {@code Meta-Display}
	 * lease using the GType already registered by {@link OLLMrpc.Gi.register}.
	 */
	public class Bootstrap : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public GLib.Object meta_display { get; private set; }

		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Bootstrap", typeof(Bootstrap));
			OLLMrpc.Request.add_class(
				"RPC-Bootstrap", typeof(Bootstrap),
				"get_display", "",
				null
			);
		}

		public static Bootstrap bind()
		{
			var bootstrap = new Bootstrap();
			bootstrap.meta_display = MockBootGraph.get().display;
			return bootstrap;
		}

		public void get_display(OLLMrpc.Request request)
		{
			request.connection.export(this.meta_display);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", this.meta_display),
			});
		}
	}
}
