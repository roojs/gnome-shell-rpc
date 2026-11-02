namespace Gsr.Server.Meta
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
	 * Gsr.Server.Meta.Compositor.rpc_register();
	 * OLLMrpc.Request.register_live("Meta-Compositor",
	 *     new Gsr.Server.Meta.Compositor(meta_display.get_compositor()));
	 * }}}
	 */
	public class Compositor : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Meta-Compositor", typeof(Compositor),
				"get_window_actors", "",
				null
			);
		}

		public global::Meta.Compositor meta_compositor { get; construct; }

		public Compositor(global::Meta.Compositor meta_compositor)
		{
			GLib.Object(meta_compositor: meta_compositor);
		}

		/**
		 * ''Meta-Compositor.get_window_actors'' — actor, then its
		 * window, as live objects. Decode constructs each proxy
		 * with its lease set. A null window is an empty object
		 * slot. The client override binds that window on the actor.
		 *
		 * @param request inbound RPC
		 */
		public void get_window_actors(OLLMrpc.Request request)
		{
			var response = new OLLMrpc.Response() {
				id = request.id,
			};
			var count = 0;
			foreach (unowned global::Meta.WindowActor actor in this.meta_compositor.get_window_actors()) {
				request.connection.export(actor);
				response.args.add(OLLMrpc.val("o", actor));
				var win = actor.get_meta_window();
				if (win == null) {
					response.args.add(OLLMrpc.val("o", null));
				}
				if (win != null) {
					request.connection.export(win);
					response.args.add(OLLMrpc.val("o", win));
				}
				count++;
			}
			GLib.debug("window actors=%d", count);
			request.reply(response);
		}
	}
}
