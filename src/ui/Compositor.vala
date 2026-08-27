namespace GnomeShellRpc.Ui
{
	/**
	 * Live {@code Meta-Compositor} RPC handler.
	 *
	 * {@link OLLMrpc.Request.register_live} keeps this singleton as
	 * {@code this}; {@code lease_id} is the compositor, not the handler.
	 *
	 * == Example ==
	 *
	 * {{{
	 * GnomeShellRpc.Ui.Compositor.rpc_register();
	 * OLLMrpc.Request.register_live("Meta-Compositor",
	 *     new GnomeShellRpc.Ui.Compositor(meta_display.get_compositor()));
	 * }}}
	 */
	public class Compositor : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Meta-Compositor", typeof(Compositor),
				"get_window_actors", "",
				"get_backend", "",
				null
			);
		}

		public Meta.Compositor meta_compositor { get; construct; }

		public Compositor(Meta.Compositor meta_compositor)
		{
			GLib.Object(meta_compositor: meta_compositor);
		}

		/**
		 * ''Meta-Compositor.get_window_actors'' — lease id per window actor.
		 *
		 * Same packing as {@link Display.get_compositor}: uint64 handles in
		 * {@link OLLMrpc.Response.args}. Live GObject rows in
		 * {@link OLLMrpc.Response.result} arrive with handle 0, which
		 * then SIGSEGVs libocrpc {@code reply_error} on Clutter RPC.
		 *
		 * @param request inbound RPC
		 */
		public void get_window_actors(OLLMrpc.Request request)
		{
			var response = new OLLMrpc.Response() {
				id = request.id,
			};
			foreach (unowned Meta.WindowActor actor in this.meta_compositor.get_window_actors()) {
				var handle = GLib.Value(typeof(uint64));
				handle.set_uint64(request.connection.export(actor));
				response.args.add(handle);
			}
			GLib.debug("window actors=%d", response.args.size);
			request.reply(response);
		}

		/**
		 * ''Meta-Compositor.get_backend'' — lease id of the backend.
		 *
		 * Same packing as {@link Display.get_compositor}.
		 *
		 * @param request inbound RPC
		 */
		public void get_backend(OLLMrpc.Request request)
		{
			var backend = this.meta_compositor.get_backend();
			var handle = (uint64) request.connection.export(backend);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}
	}
}
