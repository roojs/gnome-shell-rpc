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
		public WM window_manager { get; private set; }

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
		public signal void locate_pointer();

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
			this.window_manager = new WM(new Meta.Plugin());
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

		/**
		 * Stock {@code shell_global_create_app_launch_context} — Meta
		 * startup-notification launcher + timestamp / workspace.
		 */
		public GLib.AppLaunchContext create_app_launch_context(uint32 timestamp, int workspace)
		{
			var sn = this.display.get_startup_notification();
			var context = sn.create_launcher();
			if (context == null) {
				context = new Meta.LaunchContext();
			}
			if (timestamp == 0) {
				timestamp = this.get_current_time();
			}
			context.set_timestamp(timestamp);
			if (workspace > -1) {
				var ws = this.workspace_manager.get_workspace_by_index(workspace);
				if (ws != null) {
					context.set_workspace(ws);
				}
			}
			return context;
		}

		/**
		 * Stock {@code shell_global_get_persistent_state} — typed GVariant
		 * from {@link userdatadir}/@property_name.
		 */
		public GLib.Variant? get_persistent_state(string property_type, string property_name)
		{
			var path = GLib.File.new_for_path(this.userdatadir).get_child(property_name);
			var pathstr = path.get_path();
			if (pathstr == null) {
				return null;
			}
			try {
				var mfile = new GLib.MappedFile(pathstr, false);
				return new GLib.Variant.from_bytes(
					new GLib.VariantType(property_type), mfile.get_bytes(), false);
			} catch (GLib.FileError.NOENT e) {
				return null;
			} catch (GLib.Error e) {
				GLib.warning("Failed to open persistent state: %s", e.message);
				return null;
			}
		}

		/**
		 * Stock {@code shell_global_set_persistent_state}.
		 */
		public void set_persistent_state(string property_name, GLib.Variant? variant)
		{
			var path = GLib.File.new_for_path(this.userdatadir).get_child(property_name);
			var parent = path.get_parent();
			if (parent != null) {
				try {
					parent.make_directory_with_parents();
				} catch (GLib.IOError.EXISTS e) {
				} catch (GLib.Error e) {
					GLib.warning("Could not create persistent state dir: %s", e.message);
					return;
				}
			}
			if (variant == null || variant.get_data() == null) {
				try {
					path.@delete();
				} catch (GLib.Error e) {
				}
				return;
			}
			try {
				string? new_etag;
				path.replace_contents(variant.get_data_as_bytes().get_data(),
					null, false, GLib.FileCreateFlags.REPLACE_DESTINATION, out new_etag);
			} catch (GLib.Error e) {
				GLib.warning("Could not replace persistent state file: %s", e.message);
			}
		}

		/**
		 * Stock {@code shell_global_get_pointer} — coords + mods via
		 * {@link Meta.CursorTracker.get_pointer}.
		 */
		public void get_pointer(out int x, out int y, out Clutter.ModifierType mods)
		{
			Graphene.Point point;
			Clutter.ModifierType raw_mods;
			this.backend.get_cursor_tracker().get_pointer(out point, out raw_mods);
			x = (int) point.x;
			y = (int) point.y;
			mods = (Clutter.ModifierType) (
				(uint) raw_mods & (uint) Clutter.ModifierType.modifier_mask);
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
