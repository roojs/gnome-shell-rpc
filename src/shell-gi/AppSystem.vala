/**
 * Owned {@code Shell.AppSystem} — stock {@code shell-app-system} desktop
 * index (0.7.7 B). Loads installed apps via {@code GAppInfo}; lookups match
 * stock wmclass / StartupWMClass / vendor-prefix heuristics.
 */
namespace Shell
{
	public class AppSystem : GLib.Object
	{
		private static AppSystem? instance;
		private static string[] vendor_prefixes = {
			"gnome-", "fedora-", "mozilla-", "debian-"
		};

		private GLib.HashTable<string, App> id_to_app {
			get; set;
			default = new GLib.HashTable<string, App>(GLib.str_hash, GLib.str_equal);
		}
		private GLib.HashTable<string, string> startup_wm_class_to_id {
			get; set;
			default = new GLib.HashTable<string, string>(GLib.str_hash, GLib.str_equal);
		}
		private GLib.HashTable<App, bool> running_apps {
			get; set;
			default = new GLib.HashTable<App, bool>(GLib.direct_hash, GLib.direct_equal);
		}
		private GLib.List<GLib.AppInfo> installed_apps = new GLib.List<GLib.AppInfo>();

		public signal void app_state_changed(App app);
		public signal void installed_changed();

		public static AppSystem get_default()
		{
			if (instance == null) {
				instance = new AppSystem();
			}
			return instance;
		}

		construct {
			this.reload_installed();
		}

		private void reload_installed()
		{
			this.installed_apps = new GLib.List<GLib.AppInfo>();
			this.startup_wm_class_to_id.remove_all();
			foreach (var info in GLib.AppInfo.get_all()) {
				var desktop = info as GLib.DesktopAppInfo;
				if (desktop == null) {
					continue;
				}
				this.installed_apps.append(info);
				var startup = desktop.get_startup_wm_class();
				var id = info.get_id();
				if (startup == null || startup.length == 0 || id == null) {
					continue;
				}
				var existing = this.startup_wm_class_to_id.lookup(startup);
				if (existing == null || this.startup_wm_class_exact(id, startup)) {
					this.startup_wm_class_to_id.insert(startup, id);
				}
			}
			this.installed_changed();
		}

		private bool startup_wm_class_exact(string id, string startup)
		{
			if (!id.has_suffix(".desktop")) {
				return false;
			}
			var base_id = id.slice(0, id.length - ".desktop".length);
			return base_id == startup;
		}

		public GLib.List<weak GLib.AppInfo> get_installed()
		{
			var list = new GLib.List<weak GLib.AppInfo>();
			unowned GLib.List<GLib.AppInfo> iter = this.installed_apps;
			while (iter != null) {
				list.append(iter.data);
				iter = iter.next;
			}
			return (owned) list;
		}

		public GLib.SList<weak App> get_running()
		{
			var list = new GLib.SList<weak App>();
			this.running_apps.foreach((app, running) => {
				if (app.state == AppState.RUNNING) {
					list.append(app);
				}
			});
			return (owned) list;
		}

		public App? lookup_app(string id)
		{
			var cached = this.id_to_app.lookup(id);
			if (cached != null) {
				return cached;
			}
			var info = new GLib.DesktopAppInfo(id);
			if (info == null) {
				unowned GLib.List<GLib.AppInfo> iter = this.installed_apps;
				while (iter != null) {
					if (iter.data.get_id() == id) {
						info = iter.data as GLib.DesktopAppInfo;
						break;
					}
					iter = iter.next;
				}
			}
			if (info == null) {
				return null;
			}
			var app = new App(info);
			this.id_to_app.insert(id, app);
			return app;
		}

		public App? lookup_heuristic_basename(string name)
		{
			var result = this.lookup_app(name);
			if (result != null) {
				return result;
			}
			foreach (var prefix in vendor_prefixes) {
				result = this.lookup_app(prefix + name);
				if (result != null) {
					return result;
				}
			}
			return null;
		}

		public App? lookup_desktop_wmclass(string? wmclass)
		{
			if (wmclass == null || wmclass.length == 0) {
				return null;
			}
			var app = this.lookup_heuristic_basename(wmclass + ".desktop");
			if (app != null) {
				return app;
			}
			var canonicalized = wmclass.down().replace(" ", "-");
			return this.lookup_heuristic_basename(canonicalized + ".desktop");
		}

		public App? lookup_startup_wmclass(string? wmclass)
		{
			if (wmclass == null || wmclass.length == 0) {
				return null;
			}
			var id = this.startup_wm_class_to_id.lookup(wmclass);
			if (id == null) {
				return null;
			}
			return this.lookup_app(id);
		}

		/**
		 * Stock wrapper around {@code g_desktop_app_info_search}.
		 */
		public static string**[] search(string search_string)
		{
			return GLib.DesktopAppInfo.search(search_string);
		}

		internal void notify_app_state(App app)
		{
			switch (app.state) {
				case AppState.RUNNING:
					this.running_apps.insert(app, true);
					break;
				case AppState.STOPPED:
					this.running_apps.remove(app);
					break;
				case AppState.STARTING:
					break;
			}
			this.app_state_changed(app);
		}
	}
}
