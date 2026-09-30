/**
 * {@code Shell.App} — stock {@code shell-app.c} surface used by AppSystem /
 * WindowTracker (0.7.7 B). Desktop-backed via {@link app_info}; window-backed
 * when only a {@link Meta.Window} is known.
 */
namespace Shell
{
	public class App : GLib.Object
	{
		private Gee.ArrayList<Meta.Window> wins {
			get; set; default = new Gee.ArrayList<Meta.Window>();
		}
		private bool window_sort_stale = true;
		private GLib.Icon? fallback_icon;

		/* Vala 0.56 --gir writes GLib.DesktopAppInfo; gir-inject.xsl rewrites it. */
		public GLib.DesktopAppInfo? app_info { get; construct; default = null; }

		public string id {
			owned get {
				if (this.app_info != null && this.app_info.get_id() != null) {
					return this.app_info.get_id();
				}
				if (this.wins.size > 0) {
					return "window:" + this.wins.get(0).get_stable_sequence().to_string();
				}
				return "";
			}
		}

		public AppState state {
			get {
				if (this.wins.size > 0) {
					return AppState.RUNNING;
				}
				return AppState.STOPPED;
			}
		}

		public App(GLib.DesktopAppInfo? app_info = null)
		{
			Object(app_info: app_info);
		}

		/**
		 * Stock {@code _shell_app_new_for_window} — not a public GIR ctor.
		 */
		internal static App for_window(Meta.Window window)
		{
			var app = new App(null);
			app.add_window(window);
			return app;
		}

		public string get_name()
		{
			if (this.app_info != null) {
				return this.app_info.get_name();
			}
			if (this.wins.size > 0 && this.wins.get(0).wm_class != null) {
				return this.wins.get(0).wm_class;
			}
			return "Unknown";
		}

		public bool is_window_backed()
		{
			return this.app_info == null;
		}

		/**
		 * Stock {@code shell_app_get_icon} / property {@code icon} —
		 * desktop icon or themed fallback.
		 */
		public GLib.Icon icon {
			owned get {
				if (this.app_info != null && this.app_info.get_icon() != null) {
					return this.app_info.get_icon();
				}
				if (this.fallback_icon == null) {
					this.fallback_icon = new GLib.ThemedIcon("application-x-executable");
				}
				return this.fallback_icon;
			}
		}

		/**
		 * Stock {@code shell_app_create_icon_texture} — {@link St.Icon} bound to
		 * {@link icon} at @size.
		 */
		public Clutter.Actor create_icon_texture(int size)
		{
			var ret = new St.Icon();
			ret.icon_size = size;
			ret.fallback_icon_name = "application-x-executable";
			this.bind_property("icon", ret, "gicon", GLib.BindingFlags.SYNC_CREATE);
			if (this.is_window_backed()) {
				ret.add_style_class_name("fallback-app-icon");
			}
			return ret;
		}

		public GLib.SList<weak Meta.Window> get_windows()
		{
			if (this.window_sort_stale) {
				var active = Global.get().workspace_manager
					.get_active_workspace();
				this.wins.sort((a, b) => {
					var ws_a = a.get_workspace() == active;
					var ws_b = b.get_workspace() == active;
					if (ws_a && !ws_b) {
						return -1;
					}
					if (!ws_a && ws_b) {
						return 1;
					}
					var vis_a = a.showing_on_its_workspace();
					var vis_b = b.showing_on_its_workspace();
					if (vis_a && !vis_b) {
						return -1;
					}
					if (!vis_a && vis_b) {
						return 1;
					}
					return (int) (b.user_time - a.user_time);
				});
				this.window_sort_stale = false;
			}
			var list = new GLib.SList<weak Meta.Window>();
			foreach (var win in this.wins) {
				if (win.is_override_redirect()) {
					continue;
				}
				list.append(win);
			}
			return (owned) list;
		}

		public int get_n_windows()
		{
			return this.wins.size;
		}

		internal void add_window(Meta.Window window)
		{
			if (this.wins.contains(window)) {
				return;
			}
			this.wins.insert(0, window);
			this.window_sort_stale = true;
			this.notify_property("state");
		}

		internal void remove_window(Meta.Window window)
		{
			if (!this.wins.remove(window)) {
				return;
			}
			this.window_sort_stale = true;
			this.notify_property("state");
		}

		public async void activate_action(
			string action_name,
			GLib.Variant? parameter,
			uint timestamp,
			int workspace,
			GLib.Cancellable? cancellable
		) throws GLib.Error
		{
			if (this.app_info == null) {
				throw new GLib.IOError.FAILED(
					"Shell.App.activate_action: no DesktopAppInfo");
			}
			var raw_id = this.app_info.get_id();
			if (raw_id == null || !GLib.Application.id_is_valid(raw_id)) {
				throw new GLib.IOError.FAILED(
					"Shell.App.activate_action: invalid application id");
			}
			if (action_name.length == 0) {
				throw new GLib.IOError.INVALID_ARGUMENT(
					"Shell.App.activate_action: empty action_name");
			}
			var bus_name = raw_id;
			if (raw_id.has_suffix(".desktop")) {
				bus_name = raw_id.slice(0, raw_id.length - ".desktop".length);
			}
			var platform = new GLib.VariantBuilder(new GLib.VariantType("a{sv}"));
			var startup_id = Global.get().create_app_launch_context(timestamp, workspace)
				.get_startup_notify_id(this.app_info, new GLib.List<GLib.File>());
			if (startup_id != null) {
				platform.add("{sv}", "desktop-startup-id", new GLib.Variant.string(startup_id));
				platform.add("{sv}", "activation-token", new GLib.Variant.string(startup_id));
			}
			yield (yield GLib.Bus.@get(GLib.BusType.SESSION, cancellable)).call(
				bus_name, "/" + bus_name.replace(".", "/").replace("-", "_"),
				"org.freedesktop.Application", "ActivateAction",
				new GLib.Variant("(s@av@a{sv})", action_name,
					parameter != null ? parameter : new GLib.Variant("av", null),
					platform.end()),
				null, GLib.DBusCallFlags.NONE, -1, cancellable);
		}

		/**
		 * Stock {@code shell_app_activate} — default workspace and event
		 * timestamp. Equivalent to {@link activate_full} with -1 / 0.
		 */
		public void activate()
		{
			this.activate_full(-1, 0);
		}

		/**
		 * Stock {@code shell_app_activate_full} — default action for the
		 * app's current state. STOPPED launches; RUNNING focuses the most
		 * recent window; STARTING is a no-op.
		 *
		 * @param workspace launch on this workspace, or -1 for default;
		 *   ignored when activating an existing window
		 * @param timestamp event timestamp, or 0 for the current event time
		 */
		public void activate_full(int workspace, uint32 timestamp)
		{
			if (timestamp == 0) {
				timestamp = Global.get().get_current_time();
			}
			switch (this.state) {
				case AppState.STOPPED:
					try {
						this.launch(timestamp, workspace, AppLaunchGpu.APP_PREF);
					} catch (GLib.Error e) {
						Global.get().notify_error(
							"Failed to launch “%s”".printf(this.get_name()), e.message);
					}
					break;

				case AppState.STARTING:
					break;

				case AppState.RUNNING:
					this.activate_window(null, timestamp);
					break;

				default:
					GLib.assert_not_reached();
			}
		}

		/**
		 * Stock {@code shell_app_launch} — spawn the application via its
		 * {@link app_info} using a startup-notification launch context from
		 * {@link Global.create_app_launch_context}. Window-backed apps (no
		 * {@link app_info}) activate their first window instead.
		 *
		 * @param timestamp event timestamp, or 0 for the current event time
		 * @param workspace start on this workspace, or -1 for default
		 * @param gpu_pref GPU preference
		 * @return true if the launch was dispatched
		 */
		public bool launch(uint timestamp, int workspace, AppLaunchGpu gpu_pref) throws GLib.Error
		{
			if (this.app_info == null) {
				if (this.wins.size > 0) {
					this.wins.get(0).activate(timestamp);
				}
				return true;
			}
			var discrete = false;
			switch (gpu_pref) {
				case AppLaunchGpu.APP_PREF:
					discrete = this.app_info.get_boolean("PrefersNonDefaultGPU");
					break;

				case AppLaunchGpu.DISCRETE:
					discrete = true;
					break;

				default:
					break;
			}
			if (discrete) {
				GLib.warning("Could not apply discrete GPU environment, switcheroo-control not available");
			}
			var path = this.app_info.get_filename();
			if (path != null && path.length > 0) {
				var response = GnomeShellRpc.call_value("Helper-AppLaunch.launch_desktop_file",
					null, OLLMrpc.args("sui", path, timestamp, workspace));
				var ok = response.retval.get_boolean();
				if (!ok) {
					GLib.warning(
						"Helper-AppLaunch.launch_desktop_file returned false for %s",
						path);
				}
				return ok;
			}
			return this.app_info.launch(null,
				Global.get().create_app_launch_context(timestamp, workspace));
		}

		/**
		 * Stock {@code shell_app_launch_action} — activate a desktop action
		 * (from {@link GLib.DesktopAppInfo.list_actions}) with a
		 * startup-notification launch context.
		 *
		 * @param action_name action name from
		 *   {@link GLib.DesktopAppInfo.list_actions}
		 * @param timestamp event timestamp, or 0 for the current event time
		 * @param workspace start on this workspace, or -1 for default
		 */
		public void launch_action(string action_name, uint timestamp, int workspace)
		{
			if (this.app_info == null) {
				return;
			}
			var path = this.app_info.get_filename();
			if (path != null && path.length > 0) {
				GnomeShellRpc.call_value("Helper-AppLaunch.launch_action",
					null, OLLMrpc.args("ssui", path, action_name, timestamp, workspace));
				return;
			}
			this.app_info.launch_action(action_name,
				Global.get().create_app_launch_context(timestamp, workspace));
		}

		/**
		 * Stock {@code shell_app_open_new_window} — request a new window.
		 * Prefers a {@code new-window} desktop action, then falls back to
		 * launching the app again.
		 *
		 * First draft: the running-state {@code app.new-window} action
		 * (action muxer) branch is not applied; it lands with the
		 * running-state surface (S.28).
		 *
		 * @param workspace open on this workspace, or -1 for default
		 */
		public void open_new_window(int workspace)
		{
			if (this.app_info == null) {
				return;
			}
			if ("new-window" in this.app_info.list_actions()) {
				this.launch_action("new-window", 0, workspace);
				return;
			}
			try {
				this.launch(0, workspace, AppLaunchGpu.APP_PREF);
			} catch (GLib.Error e) {
				/* stock ignores launch errors on the fallback path */
			}
		}

		/**
		 * Stock {@code shell_app_can_open_new_window} — whether
		 * {@link open_new_window} will actually open a new window. Stopped
		 * apps always can; running apps consult the desktop file's
		 * {@code SingleMainWindow} / {@code X-GNOME-SingleWindow} keys and
		 * {@code new-window} action.
		 *
		 * First draft: the running-state {@code app.new-window} action and
		 * unique-bus / GtkApplication-id checks (action muxer) are not
		 * applied; they land with the running-state surface (S.28).
		 *
		 * @return true if a new window can be opened
		 */
		public bool can_open_new_window()
		{
			if (this.state != AppState.RUNNING) {
				return this.state == AppState.STOPPED;
			}
			if (this.app_info == null) {
				return false;
			}
			if (this.app_info.has_key("SingleMainWindow")) {
				return !this.app_info.get_boolean("SingleMainWindow");
			}
			if (this.app_info.has_key("X-GNOME-SingleWindow")) {
				return !this.app_info.get_boolean("X-GNOME-SingleWindow");
			}
			if ("new-window" in this.app_info.list_actions()) {
				return true;
			}
			return true;
		}

		/**
		 * Stock {@code shell_app_activate_window} — bring the app's windows
		 * to the foreground with @window on top. If @window is null, the
		 * most-recent window is used. No effect if the app is not running.
		 *
		 * @param window window to focus, or null for the most recent
		 * @param timestamp event timestamp
		 */
		public void activate_window(Meta.Window? window, uint32 timestamp)
		{
			if (this.state != AppState.RUNNING) {
				return;
			}
			var windows = this.get_windows();
			if (window == null && windows != null) {
				window = windows.data;
			}
			if (windows.find(window) == null) {
				return;
			}
			var workspace = window.get_workspace();
			if (Global.get().display.xserver_time_is_before(
					timestamp, Global.get().display.get_last_user_time())) {
				window.set_demands_attention();
				return;
			}
			var reversed = windows.copy();
			reversed.reverse();
			foreach (var other in reversed) {
				if (other == window) {
					continue;
				}
				other.raise_and_make_recent_on_workspace(workspace);
			}
			var transients = new GLib.SList<Meta.Window>();
			window.foreach_transient((w) => {
				if (workspace != null && w.get_workspace() != workspace) {
					return true;
				}
				transients.prepend(w);
				return true;
			});
			var sorted = Global.get().display.sort_windows_by_stacking(transients);
			sorted.reverse();
			var most_recent_transient = window;
			foreach (var w in sorted) {
				switch (w.window_type) {
					case Meta.WindowType.normal:
					case Meta.WindowType.dialog:
						most_recent_transient = w;
						break;

					default:
						continue;
				}
				break;
			}
			if (Global.get().display.xserver_time_is_before(
					window.user_time, most_recent_transient.user_time)) {
				window = most_recent_transient;
			}
			if (Global.get().workspace_manager.get_active_workspace() != workspace) {
				workspace.activate_with_focus(window, timestamp);
				return;
			}
			window.activate(timestamp);
		}

		/**
		 * Stock {@code shell_app_request_quit} — asynchronous quit request.
		 * Closes every closeable window of the running app.
		 *
		 * First draft: the {@code app.quit} action (action muxer) branch is
		 * not applied; it lands with the running-state surface (S.28).
		 *
		 * @return true if a quit request was dispatched
		 */
		public bool request_quit()
		{
			if (this.state != AppState.RUNNING) {
				return false;
			}
			foreach (var win in this.wins) {
				if (!win.can_close()) {
					continue;
				}
				win.delete(Global.get().get_current_time());
			}
			return true;
		}
	}
}
