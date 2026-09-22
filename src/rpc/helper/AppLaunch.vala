/**
 * Compositor-side {@link Gio.AppInfo.launch} for out-of-process shell.
 *
 * Wire prefix ''Helper-AppLaunch''. Stock gnome-shell launches from the
 * compositor process; {@code gnome-shell-rpc} must not {@code Gio.spawn}
 * as a {@code Meta.WaylandClient} child (see search launch bug D″).
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class AppLaunch : GLib.Object
	{
		public Meta.Display meta_display { get; construct; }

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-AppLaunch", typeof(AppLaunch),
				"launch_commandline", "sui",
				"launch_desktop_file", "sui",
				"launch_action", "ssui",
				null
			);
		}

		public static void bind(Meta.Display display)
		{
			OLLMrpc.Request.register_live("Helper-AppLaunch", new AppLaunch(display));
		}

		public AppLaunch(Meta.Display meta_display)
		{
			GLib.Object(
				meta_display: meta_display
			);
		}

		/**
		 * Same shape as stock {@code shell_global_create_app_launch_context}:
		 * mutter {@code create_launcher()} only — no Helper {@code setenv} /
		 * {@code unset DISPLAY} (see
		 * {@code docs/bugs/2026-09-22-search-result-click-no-launch.md} D′).
		 */
		private GLib.AppLaunchContext make_launch_context(uint timestamp, int workspace)
		{
			var sn = this.meta_display.get_startup_notification();
			GLib.AppLaunchContext context = sn.create_launcher();
			if (context == null) {
				context = new GLib.AppLaunchContext();
			}
			if (timestamp == 0) {
				timestamp = (uint) (GLib.get_monotonic_time() / 1000);
			}
			var meta_ctx = context as Meta.LaunchContext;
			if (meta_ctx != null) {
				meta_ctx.set_timestamp(timestamp);
				if (workspace > -1) {
					var mgr = this.meta_display.get_workspace_manager();
					var ws = mgr.get_workspace_by_index(workspace);
					if (ws != null) {
						meta_ctx.workspace = ws;
					}
				}
			}
			return context;
		}

		public void launch_commandline(
			OLLMrpc.Request request,
			string cmd,
			uint timestamp,
			int workspace
		) {
			bool ok = false;
			try {
				var ctx = this.make_launch_context(timestamp, workspace);
				var app = GLib.AppInfo.create_from_commandline(
					cmd, null, GLib.AppInfoCreateFlags.NONE);
				if (app == null) {
					throw new GLib.IOError.FAILED("create_from_commandline failed");
				}
				ok = app.launch(null, ctx);
			} catch (GLib.Error e) {
				GLib.warning("Helper-AppLaunch.launch_commandline: %s", e.message);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
			});
		}

		public void launch_desktop_file(
			OLLMrpc.Request request,
			string path,
			uint timestamp,
			int workspace
		) {
			bool ok = false;
			try {
				var ctx = this.make_launch_context(timestamp, workspace);
				var app = new GLib.DesktopAppInfo.from_filename(path);
				if (app == null) {
					throw new GLib.IOError.FAILED("from_filename failed");
				}
				ok = app.launch(null, ctx);
			} catch (GLib.Error e) {
				GLib.warning("Helper-AppLaunch.launch_desktop_file: %s", e.message);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
			});
		}

		public void launch_action(
			OLLMrpc.Request request,
			string path,
			string action_name,
			uint timestamp,
			int workspace
		) {
			bool ok = false;
			try {
				var ctx = this.make_launch_context(timestamp, workspace);
				var app = new GLib.DesktopAppInfo.from_filename(path);
				if (app == null) {
					throw new GLib.IOError.FAILED("from_filename failed");
				}
				app.launch_action(action_name, ctx);
				ok = true;
			} catch (GLib.Error e) {
				GLib.warning("Helper-AppLaunch.launch_action: %s", e.message);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
			});
		}
	}
}
