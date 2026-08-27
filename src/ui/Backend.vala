namespace GnomeShellRpc.Ui
{
	/**
	 * Live {@code Meta-Backend} RPC handler.
	 *
	 * {@link OLLMrpc.Request.register_live} keeps this singleton as
	 * {@code this}; {@code lease_id} is the backend, not the handler.
	 *
	 * == Example ==
	 *
	 * {{{
	 * GnomeShellRpc.Ui.Backend.rpc_register();
	 * OLLMrpc.Request.register_live("Meta-Backend",
	 *     new GnomeShellRpc.Ui.Backend(meta_display.get_context().get_backend()));
	 * }}}
	 */
	public class Backend : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Meta-Backend", typeof(Backend),
				"get_core_idle_monitor", "",
				null
			);
		}

		public Meta.Backend meta_backend { get; construct; }

		public Backend(Meta.Backend meta_backend)
		{
			GLib.Object(meta_backend: meta_backend);
		}

		/**
		 * ''Meta-Backend.get_core_idle_monitor'' — lease id of the monitor.
		 *
		 * Same packing as {@link Display.get_compositor}: uint64 handle in
		 * {@link OLLMrpc.Response.args}. Live GObject rows in
		 * {@link OLLMrpc.Response.result} arrive with handle 0.
		 *
		 * @param request inbound RPC
		 */
		public void get_core_idle_monitor(OLLMrpc.Request request)
		{
			var monitor = this.meta_backend.get_core_idle_monitor();
			var handle = (uint64) request.connection.export(monitor);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}
	}
}
