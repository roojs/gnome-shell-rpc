namespace Gsr.Server
{
	/**
	 * Mutter compositor plugin: opaque stage plus local effect completion.
	 *
	 * start() paints a solid {@link global::Meta.BackgroundActor} per monitor
	 * (same slot as mutter's libdefault). Without that, nested mode
	 * never clears the framebuffer and the software cursor trails.
	 *
	 * Those actors are only a pre-RPC placeholder. Shell layout also
	 * inserts a {@link global::Meta.BackgroundGroup} at the bottom of
	 * {@code window_group}; if the placeholder stays, it sits
	 * *above* the shell wallpaper and covers it. First
	 * {@link Gsr.Server.Meta.BackgroundActor.create} drops the placeholder.
	 *
	 * map / minimize / unminimize / destroy complete immediately (no
	 * animation). Leaving those vfuncs unset does **not** fall through
	 * to libdefault — this process replaced that plugin type.
	 *
	 * == Example ==
	 *
	 * {{{
	 * var ctx = new global::Meta.Context("Mutter(GnomeShellRpc)");
	 * ctx.set_plugin_gtype(typeof(Gsr.Server.Plugin));
	 * ctx.setup();
	 * ctx.start();
	 * ctx.run_main_loop();
	 * }}}
	 */
	public class Plugin : global::Meta.Plugin
	{
		private static weak Plugin? instance;

		private Gsr.Server.Rpc.Server rpc_server;
		private global::Meta.BackgroundGroup? placeholder_backgrounds;
		private ulong monitors_changed_id;

		public override void start()
		{
			Plugin.instance = this;
			var display = this.get_display();
			var backend = display.get_context().get_backend();
			this.placeholder_backgrounds = new global::Meta.BackgroundGroup();
			display.get_compositor().get_window_group().insert_child_below(
				this.placeholder_backgrounds, null);

			this.monitors_changed_id = backend.get_monitor_manager()
				.monitors_changed.connect(() => {
					this.refill_placeholder_backgrounds();
				});
			this.refill_placeholder_backgrounds();

			backend.get_stage().show();
			this.rpc_server = new Gsr.Server.Rpc.Server();
			this.rpc_server.start(display);
			GLib.debug("stage shown");
		}

		/**
		 * Drop the pre-RPC clear-fill so shell {@link global::Meta.BackgroundActor}
		 * wallpaper is visible.
		 */
		public static void release_placeholder_backgrounds()
		{
			Plugin.instance?.drop_placeholder_backgrounds();
		}

		private void drop_placeholder_backgrounds()
		{
			if (this.placeholder_backgrounds == null) {
				return;
			}
			if (this.monitors_changed_id != 0) {
				this.get_display().get_context().get_backend()
					.get_monitor_manager()
					.disconnect(this.monitors_changed_id);
				this.monitors_changed_id = 0;
			}
			this.placeholder_backgrounds.destroy();
			this.placeholder_backgrounds = null;
			GLib.debug("released placeholder backgrounds for shell wallpaper");
		}

		private void refill_placeholder_backgrounds()
		{
			if (this.placeholder_backgrounds == null) {
				return;
			}
			this.placeholder_backgrounds.destroy_all_children();
			var display = this.get_display();
			for (var i = 0; i < display.get_n_monitors(); i++) {
				var rect = display.get_monitor_geometry(i);
				var background_actor = new global::Meta.BackgroundActor(display, i);
				background_actor.set_position(rect.x, rect.y);
				background_actor.set_size(rect.width, rect.height);
				var background = new global::Meta.Background(display);
				background.set_color(Cogl.Color.from_4f(0.18f, 0.20f, 0.21f, 1.0f));
				var background_content = (global::Meta.BackgroundContent) background_actor.content;
				background_content.set_background(background);
				background_content.set_vignette(true, 0.5, 0.5);
				this.placeholder_backgrounds.add_child(background_actor);
			}
		}

		public override void map(global::Meta.WindowActor actor)
		{
			actor.show();
			this.map_completed(actor);
		}

		public override void minimize(global::Meta.WindowActor actor)
		{
			actor.hide();
			this.minimize_completed(actor);
		}

		public override void unminimize(global::Meta.WindowActor actor)
		{
			actor.show();
			this.unminimize_completed(actor);
		}

		public override void destroy(global::Meta.WindowActor actor)
		{
			this.destroy_completed(actor);
		}
	}
}
