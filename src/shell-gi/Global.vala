/**
 * Owned {@code Shell.Global} for gnome-shell-rpc (0.7.7 S0/S1).
 *
 * Not stock libshell. Host calls {@link bind_display} after
 * {@code Runtime.register()}.
 */
namespace Shell
{
	public class Global : GLib.Object
	{
		private static Global? instance;
		private int work_count = 0;
		private GLib.Settings? settings_cache;
		private St.FocusManager? focus_manager_cache;

		public Meta.Display display { get; construct; }
		public Clutter.Stage stage { get; construct; }
		public Meta.Backend backend { get; construct; }
		public Meta.Context context { get; construct; }
		public Meta.Compositor compositor { get; construct; }

		public string datadir { get; construct; }
		public string userdatadir { get; construct; }
		public string session_mode { get; construct; }

		public GLib.Settings settings {
			get {
				if (this.settings_cache == null) {
					this.settings_cache = new GLib.Settings("org.gnome.shell");
				}
				return this.settings_cache;
			}
		}

		public St.FocusManager focus_manager {
			get {
				if (this.focus_manager_cache == null) {
					this.focus_manager_cache =
						St.FocusManager.get_for_stage(this.stage);
				}
				return this.focus_manager_cache;
			}
		}

		public signal void notify_error(string msg, string details);
		public signal void shutdown();

		/**
		 * Stock {@code shell_global_get} — singleton after {@link bind_display}.
		 */
		public static new unowned Global get()
		{
			if (instance == null) {
				GLib.error("Shell.Global.get: host must call bind_display first");
			}
			return instance;
		}

		/**
		 * @param display leased Meta.Display from {@code Meta.get_display()}
		 */
		public Global(Meta.Display display)
		{
			var context = display.get_context();
			var backend = context.get_backend();
			var mode = GLib.Environment.get_variable("GNOME_SHELL_SESSION_MODE");
			if (mode == null || mode.length == 0) {
				mode = "user";
			}
			Object(
				display: display,
				context: context,
				backend: backend,
				compositor: display.get_compositor(),
				stage: (Clutter.Stage) backend.get_stage(),
				datadir: "/usr/share/gnome-shell",
				userdatadir: GLib.Path.build_filename(
					GLib.Environment.get_user_data_dir(), "gnome-shell"),
				session_mode: mode
			);
		}

		/**
		 * Fill leases from the compositor display (host only).
		 *
		 * @param display leased Meta.Display from {@code Meta.get_display()}
		 */
		[CCode (gir = false)]
		public static void bind_display(Meta.Display display)
		{
			if (instance != null) {
				return;
			}
			instance = new Global(display);
		}

		public void begin_work()
		{
			this.work_count++;
		}

		public void end_work()
		{
			if (this.work_count > 0) {
				this.work_count--;
			}
		}

		public uint32 get_current_time()
		{
			return 0;
		}
	}
}
