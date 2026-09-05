/**
 * Owned {@code Shell.WindowTracker} — stock {@code shell-window-tracker}
 * (0.7.7 T-040). Associates {@link Meta.Window}s with {@link App} via
 * AppSystem lookups; tracks focus on the leased {@link Global.display}.
 */
namespace Shell
{
	public class WindowTracker : GLib.Object
	{
		private static WindowTracker? instance;
		private GLib.HashTable<Meta.Window, App> window_to_app {
			get; set;
			default = new GLib.HashTable<Meta.Window, App>(GLib.direct_hash, GLib.direct_equal);
		}
		private App? focus_app_cache;

		public App? focus_app {
			get {
				return this.focus_app_cache;
			}
		}

		public signal void startup_sequence_changed(Meta.StartupSequence sequence);
		public signal void tracked_windows_changed();

		public static WindowTracker get_default()
		{
			if (instance == null) {
				instance = new WindowTracker();
			}
			return instance;
		}

		construct {
			/* Ensure desktop index exists before associating windows. */
			AppSystem.get_default();
			var display = Global.get().display;
			var windows = display.list_all_windows();
			foreach (var window in windows) {
				this.track_window(window);
			}
			display.window_created.connect(this.on_window_created);
			display.focus_window.connect((win, timestamp) => {
				this.update_focus_app();
			});
			this.update_focus_app();
			Global.get().shutdown.connect(this.on_shutdown);
		}

		private void on_window_created(Meta.Window window)
		{
			this.track_window(window);
		}

		private void on_shutdown()
		{
			var keys = this.window_to_app.get_keys();
			foreach (var window in keys) {
				this.disassociate_window(window);
			}
		}

		private void track_window(Meta.Window window)
		{
			if (this.window_to_app.lookup(window) != null) {
				return;
			}
			var app = this.app_for_window(window);
			this.window_to_app.insert(window, app);
			app.add_window(window);
			AppSystem.get_default().notify_app_state(app);
			window.unmanaged.connect(() => {
				this.disassociate_window(window);
			});
			this.tracked_windows_changed();
			this.update_focus_app();
		}

		private void disassociate_window(Meta.Window window)
		{
			var app = this.window_to_app.lookup(window);
			if (app == null) {
				return;
			}
			this.window_to_app.remove(window);
			app.remove_window(window);
			AppSystem.get_default().notify_app_state(app);
			this.tracked_windows_changed();
			this.update_focus_app();
		}

		private App app_for_window(Meta.Window window)
		{
			var transient = window.get_transient_for();
			if (transient != null) {
				return this.app_for_window(transient);
			}
			var appsys = AppSystem.get_default();
			var app = this.app_from_wmclass(window);
			if (app != null) {
				return app;
			}
			var sandboxed = window.get_sandboxed_app_id();
			if (sandboxed != null && sandboxed.length > 0) {
				app = appsys.lookup_app(sandboxed + ".desktop");
				if (app != null) {
					return app;
				}
			}
			var gtk_id = window.gtk_application_id;
			if (gtk_id != null && gtk_id.length > 0) {
				app = appsys.lookup_app(gtk_id + ".desktop");
				if (app != null) {
					return app;
				}
			}
			return App.for_window(window);
		}

		private App? app_from_wmclass(Meta.Window window)
		{
			var appsys = AppSystem.get_default();
			var wm_class = window.wm_class;
			var wm_instance = window.get_wm_class_instance();
			var app = appsys.lookup_startup_wmclass(wm_class);
			if (app != null) {
				return app;
			}
			app = appsys.lookup_desktop_wmclass(wm_instance);
			if (app != null) {
				return app;
			}
			return appsys.lookup_desktop_wmclass(wm_class);
		}

		private void update_focus_app()
		{
			var focus_win = Global.get().display.get_focus_window();
			while (focus_win != null && focus_win.skip_taskbar) {
				focus_win = focus_win.get_transient_for();
			}
			App? new_focus = null;
			if (focus_win != null) {
				new_focus = this.get_window_app(focus_win);
			}
			if (this.focus_app_cache == new_focus) {
				return;
			}
			this.focus_app_cache = new_focus;
			this.notify_property("focus-app");
		}

		public App? get_app_from_pid(int pid)
		{
			foreach (var window in this.window_to_app.get_keys()) {
				if (window.get_pid() == pid) {
					return this.window_to_app.lookup(window);
				}
			}
			return null;
		}

		public App? get_window_app(Meta.Window metawin)
		{
			return this.window_to_app.lookup(metawin);
		}

		public GLib.SList<Meta.StartupSequence> get_startup_sequences()
		{
			var sn = Global.get().display.get_startup_notification();
			if (sn == null) {
				return new GLib.SList<Meta.StartupSequence>();
			}
			return sn.get_sequences();
		}
	}
}
