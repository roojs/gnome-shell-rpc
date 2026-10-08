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
		 * ''Meta-Compositor.get_window_actors'' — handle pairs per actor.
		 *
		 * List packing stays hand-rolled (uint64 args): each actor is
		 * followed by its window's lease, so a future client override
		 * can bind the hydrated actor proxy without a second round
		 * trip (mirrors ''Meta-Display.list_windows'' snapshot
		 * hydration). A zero window handle means the actor has no
		 * window. The current generated client ignores the extra
		 * args; retval stays unset until the override lands.
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
				var handle = GLib.Value(typeof(uint64));
				handle.set_uint64(request.connection.export(actor));
				response.args.add(handle);
				var win = actor.get_meta_window();
				uint64 win_lid = 0;
				if (win != null) {
					win_lid = request.connection.export(win);
				}
				var win_handle = GLib.Value(typeof(uint64));
				win_handle.set_uint64(win_lid);
				response.args.add(win_handle);
				count++;
			}
			GLib.debug("window actors=%d", count);
			request.reply(response);
		}
	}
}
