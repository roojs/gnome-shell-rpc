/**
 * {@code Shell.App} — stock {@code shell-app.c} surface used by AppSystem /
 * WindowTracker (0.7.7 B). Desktop-backed via {@link app_info}; window-backed
 * when only a {@link Meta.Window} is known.
 */
namespace Shell
{
	public class App : GLib.Object
	{
		private GLib.List<Meta.Window> windows = new GLib.List<Meta.Window>();

		public GLib.DesktopAppInfo? app_info { get; construct; default = null; }

		public string id {
			owned get {
				if (this.app_info != null) {
					var desktop_id = this.app_info.get_id();
					if (desktop_id != null) {
						return desktop_id;
					}
				}
				if (this.windows.length() > 0) {
					var wm = this.windows.data.wm_class;
					if (wm != null && wm.length > 0) {
						return "window:" + wm;
					}
				}
				return "";
			}
		}

		public AppState state {
			get {
				if (this.windows.length() > 0) {
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
				return this.app_info.get_display_name();
			}
			if (this.windows.length() < 1) {
				return "";
			}
			var title = this.windows.data.title;
			if (title != null && title.length > 0) {
				return title;
			}
			var wm = this.windows.data.wm_class;
			if (wm != null) {
				return wm;
			}
			return "";
		}

		public bool is_window_backed()
		{
			return this.app_info == null;
		}

		public GLib.List<weak Meta.Window> get_windows()
		{
			var list = new GLib.List<weak Meta.Window>();
			unowned GLib.List<Meta.Window> iter = this.windows;
			while (iter != null) {
				list.append(iter.data);
				iter = iter.next;
			}
			return (owned) list;
		}

		public int get_n_windows()
		{
			return (int) this.windows.length();
		}

		internal void add_window(Meta.Window window)
		{
			unowned GLib.List<Meta.Window> iter = this.windows;
			while (iter != null) {
				if (iter.data == window) {
					return;
				}
				iter = iter.next;
			}
			this.windows.append(window);
			this.notify_property("state");
		}

		internal void remove_window(Meta.Window window)
		{
			unowned GLib.List<Meta.Window> found = this.windows.find(window);
			if (found == null) {
				return;
			}
			this.windows.remove(window);
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
			if (raw_id == null || raw_id.length == 0) {
				throw new GLib.IOError.FAILED(
					"Shell.App.activate_action: missing application id");
			}
			var bus_name = raw_id;
			if (raw_id.has_suffix(".desktop")) {
				bus_name = raw_id.slice(0, raw_id.length - ".desktop".length);
			}
			if (!GLib.Application.id_is_valid(bus_name)) {
				throw new GLib.IOError.FAILED(
					"Shell.App.activate_action: invalid application id");
			}
			if (action_name.length == 0) {
				throw new GLib.IOError.INVALID_ARGUMENT(
					"Shell.App.activate_action: empty action_name");
			}

			var param = parameter ?? new GLib.Variant("av", null);
			var platform = new GLib.Variant("a{sv}", null);
			var args = new GLib.Variant("(s@av@a{sv})",
				action_name, param, platform);

			var bus = yield GLib.Bus.@get(GLib.BusType.SESSION, cancellable);
			yield bus.call(
				bus_name,
				"/" + bus_name.replace(".", "/").replace("-", "_"),
				"org.freedesktop.Application",
				"ActivateAction",
				args,
				null,
				GLib.DBusCallFlags.NONE,
				-1,
				cancellable
			);
		}
	}
}
