namespace GnomeShellRpc.Ui
{
	/**
	 * Live {@code Meta-Context} RPC handler.
	 *
	 * {@link OLLMrpc.Request.register_live} keeps this singleton as
	 * {@code this}; {@code lease_id} is the context, not the handler.
	 *
	 * == Example ==
	 *
	 * {{{
	 * GnomeShellRpc.Ui.Context.rpc_register();
	 * OLLMrpc.Request.register_live("Meta-Context",
	 *     new GnomeShellRpc.Ui.Context(meta_display.get_context()));
	 * }}}
	 */
	public class Context : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Meta-Context", typeof(Context),
				"get_backend", "",
				null
			);
		}

		public Meta.Context meta_context { get; construct; }

		public Context(Meta.Context meta_context)
		{
			GLib.Object(meta_context: meta_context);
		}

		/**
		 * ''Meta-Context.get_backend'' — lease id of the backend.
		 *
		 * Same packing as {@link Display.get_compositor}: uint64 handle in
		 * {@link OLLMrpc.Response.args}. Live GObject rows in
		 * {@link OLLMrpc.Response.result} arrive with handle 0.
		 *
		 * @param request inbound RPC
		 */
		public void get_backend(OLLMrpc.Request request)
		{
			var backend = this.meta_context.get_backend();
			var handle = (uint64) request.connection.export(backend);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}
	}
}
