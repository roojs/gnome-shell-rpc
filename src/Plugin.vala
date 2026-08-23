namespace GnomeShellRpc
{
	/**
	 * Mutter compositor plugin: opaque stage plus local effect completion.
	 *
	 * start() paints a solid {@link Meta.BackgroundActor} per monitor
	 * (same slot as mutter's libdefault). Without that, nested mode
	 * never clears the framebuffer and the software cursor trails.
	 *
	 * map / minimize / unminimize / destroy complete immediately (no
	 * animation). Leaving those vfuncs unset does **not** fall through
	 * to libdefault — this process replaced that plugin type.
	 *
	 * == Example ==
	 *
	 * {{{
	 * var ctx = new Meta.Context("Mutter(GnomeShellRpc)");
	 * ctx.set_plugin_gtype(typeof(GnomeShellRpc.Plugin));
	 * ctx.setup();
	 * ctx.start();
	 * ctx.run_main_loop();
	 * }}}
	 */
	public class Plugin : Meta.Plugin
	{
		private Rpc.Server rpc_server;

		public override void start()
		{
			var display = this.get_display();
			var backend = display.get_context().get_backend();
			var background_group = new Meta.BackgroundGroup();
			display.get_compositor().get_window_group().insert_child_below(background_group, null);

			var manager = backend.get_monitor_manager();
			manager.monitors_changed.connect(() => {
				background_group.destroy_all_children();
				var n = display.get_n_monitors();
				for (var i = 0; i < n; i++) {
					var rect = display.get_monitor_geometry(i);
					var background_actor = new Meta.BackgroundActor(display, i);
					background_actor.set_position(rect.x, rect.y);
					background_actor.set_size(rect.width, rect.height);
					var background = new Meta.Background(display);
					background.set_color(Cogl.Color.from_4f(0.18f, 0.20f, 0.21f, 1.0f));
					var background_content = (Meta.BackgroundContent)background_actor.content;
					background_content.set_background(background);
					background_content.set_vignette(true, 0.5, 0.5);
					background_group.add_child(background_actor);
				}
			});
			manager.monitors_changed();

			backend.get_stage().show();
			this.rpc_server = new Rpc.Server();
			this.rpc_server.start(display);
			GLib.debug("stage shown");
		}

		public override void map(Meta.WindowActor actor)
		{
			actor.show();
			this.map_completed(actor);
		}

		public override void minimize(Meta.WindowActor actor)
		{
			actor.hide();
			this.minimize_completed(actor);
		}

		public override void unminimize(Meta.WindowActor actor)
		{
			actor.show();
			this.unminimize_completed(actor);
		}

		public override void destroy(Meta.WindowActor actor)
		{
			this.destroy_completed(actor);
		}
	}
}
