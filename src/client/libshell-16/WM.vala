/**
 * Owned {@code Shell.WM} — stock {@code shell-wm} (0.7.7 phase 6).
 *
 * Completion methods forward to {@link Meta.Plugin} exactly as stock
 * {@code shell_wm_completed_*} → {@code meta_plugin_*_completed}. Signals are
 * the mutter→JS effect hooks ({@code WindowManager} connects them).
 */
namespace Shell
{
	public class WM : GLib.Object
	{
		public Meta.Plugin plugin { get; construct; }

		public WM(Meta.Plugin plugin)
		{
			Object(plugin: plugin);
		}

		construct {
			/* Server Plugin.map shows the actor itself. This signal is
			 * what Desktop Icons uses to lower that window. */
			Gsr.Client.Rpc.client.notification.connect((notif) => {
				if (notif.method != "Shell-WM.map") {
					return;
				}
				var lid = (uint64) notif.id;
				if (lid == 0 || Gsr.Client.Rpc.client == null) {
					return;
				}
				var key = (int) lid;
				if (!Gsr.Client.Rpc.client.proxies.has_key(key)) {
					var created = new Meta.Window();
					created.rpc_lid = lid;
					Gsr.Client.Rpc.register_handle(created);
				}
				var win = Gsr.Client.Rpc.client.proxies.get(key) as Meta.Window;
				if (win == null) {
					return;
				}
				var actor = win.get_compositor_private() as Meta.WindowActor;
				if (actor == null) {
					return;
				}
				this.map(actor);
				GLib.debug("Shell.WM map lid=%s", lid.to_string());
			});
		}

		public void complete_display_change(bool ok)
		{
			this.plugin.complete_display_change(ok);
		}

		public void completed_destroy(Meta.WindowActor actor)
		{
			this.plugin.destroy_completed(actor);
		}

		/**
		 * Stock JS calls this when a map effect finishes.
		 *
		 * The server plugin already called {@code map_completed} before
		 * emitting {@code Shell-WM.map}. This {@code plugin} is the
		 * stand-in from {@link Global}, and forwarding the call logs
		 * {@code no rpc_lid on MetaPlugin}.
		 */
		public void completed_map(Meta.WindowActor actor)
		{
		}

		public void completed_minimize(Meta.WindowActor actor)
		{
			this.plugin.minimize_completed(actor);
		}

		public void completed_size_change(Meta.WindowActor actor)
		{
			this.plugin.size_change_completed(actor);
		}

		/**
		 * Stock JS calls this when a workspace switch effect finishes.
		 *
		 * The compositor has already finished the switch. The server
		 * plugin does not implement {@code switch_workspace}, so mutter
		 * does not wait. This {@code plugin} is a leased stand-in, and
		 * forwarding completed runs switch accounting on that stand-in.
		 */
		public void completed_switch_workspace()
		{
		}

		public void completed_unminimize(Meta.WindowActor actor)
		{
			this.plugin.unminimize_completed(actor);
		}

		public signal void confirm_display_change();
		public signal Meta.CloseDialog create_close_dialog(Meta.Window window);
		public signal Meta.InhibitShortcutsDialog create_inhibit_shortcuts_dialog(
			Meta.Window window);
		public signal void destroy(Meta.WindowActor object);
		public signal bool filter_keybinding(Meta.KeyBinding object);
		public signal void hide_tile_preview();
		public signal void kill_switch_workspace();
		public signal void kill_window_effects(Meta.WindowActor object);
		public signal void map(Meta.WindowActor object);
		public signal void minimize(Meta.WindowActor object);
		public signal void show_tile_preview(
			Meta.Window object, Mtk.Rectangle p0, int p1);
		public signal void show_window_menu(
			Meta.Window object, int p0, Mtk.Rectangle p1);
		public signal void size_change(
			Meta.WindowActor object,
			Meta.SizeChange p0,
			Mtk.Rectangle p1,
			Mtk.Rectangle p2);
		public signal void size_changed(Meta.WindowActor object);
		public signal void switch_workspace(int object, int p0, int p1);
		public signal void unminimize(Meta.WindowActor object);
	}
}
