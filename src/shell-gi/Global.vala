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

		public Meta.WorkspaceManager workspace_manager { get; private set; }
		public Clutter.Actor window_group { get; private set; }
		public Clutter.Actor top_window_group { get; private set; }

		public int screen_width { get; private set; }
		public int screen_height { get; private set; }

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

		construct {
			this.workspace_manager = this.display.get_workspace_manager();
			this.window_group = this.compositor.get_window_group();
			this.top_window_group = this.compositor.get_top_window_group();
			this.refresh_screen_size();
			this.stage.notify["width"].connect(this.on_stage_size_changed);
			this.stage.notify["height"].connect(this.on_stage_size_changed);
			this.update_scaling_factor();
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

		private void on_stage_size_changed()
		{
			this.refresh_screen_size();
		}

		private void refresh_screen_size()
		{
			int width, height;
			this.display.get_size(out width, out height);
			if (this.screen_width != width) {
				this.screen_width = width;
			}
			if (this.screen_height != height) {
				this.screen_height = height;
			}
		}

		private void update_scaling_factor()
		{
			int factor;
			try {
				var response = GnomeShellRpc.call_value(
					"Helper-Settings.get_ui_scaling_factor", null);
				factor = response.retval.get_int();
			} catch (GLib.Error e) {
				GLib.warning("update_scaling_factor: %s", e.message);
				factor = 1;
			}
			if (factor < 1) {
				factor = 1;
			}
			St.ThemeContext.get_for_stage(this.stage).scale_factor = factor;
		}
	}
}
