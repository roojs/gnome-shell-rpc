/**
 * gnome-shell-rpc thin host — no libshell (0.7.7).
 *
 * {@code Runtime.register()} → {@link Shell.Global.bind_display} → own
 * {@link Gjs.Context} → eval {@code init.js}.
 */
namespace Gsr.Client
{
	public class Application : GLib.Application, Gsr.ApplicationInterface
	{
		private const string APPLICATION_ID = "org.gnome.ShellRpc";

		private static bool opt_debug = false;
		private static bool opt_debug_critical = false;
		private static bool opt_disable_extensions = false;

		private const GLib.OptionEntry[] options = {
			{ "debug", 'd', 0, GLib.OptionArg.NONE, ref opt_debug, "Enable debug output", null },
			{ "debug-critical", 0, 0, GLib.OptionArg.NONE, ref opt_debug_critical, "Treat critical warnings as errors", null },
			{ "disable-extensions", 0, 0, GLib.OptionArg.NONE, ref opt_disable_extensions, "Start with user extensions off", null },
			{ null }
		};

		public Application()
		{
			GLib.Object(
				application_id: APPLICATION_ID,
				flags: GLib.ApplicationFlags.HANDLES_COMMAND_LINE
					| GLib.ApplicationFlags.NON_UNIQUE
			);

			GLib.Log.set_default_handler((dom, lvl, msg) => {
				Gsr.ApplicationInterface.debug_log(
					this.get_application_id(), dom, lvl, msg
				);
			});
		}

		/**
		 * @param command_line the invocation
		 * @param summary {@link GLib.OptionContext} parameter string
		 * @param remaining argv after switches; index 0 is the program
		 * @return 0, or 1 when the user passed a bad option
		 */
		protected int parse_options(
			GLib.ApplicationCommandLine command_line,
			string summary,
			out string[] remaining)
		{
			Application.opt_debug = false;
			Application.opt_debug_critical = false;
			Application.opt_disable_extensions = false;

			var args = command_line.get_arguments();
			var opt_context = new GLib.OptionContext(summary);
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(Application.options, null);

			unowned string[] parsed = args;
			try {
				opt_context.parse(ref parsed);
			} catch (GLib.OptionError e) {
				command_line.printerr("error: %s\n", e.message);
				remaining = args;
				return 1;
			}

			Gsr.debug_on = Application.opt_debug;
			Gsr.debug_critical_enabled = Application.opt_debug_critical;
			remaining = parsed;
			return 0;
		}

		/**
		 * Typelibs, RPC register, display bind, extension policy.
		 */
		protected void prepare_host()
		{
			/* Open libgvc by path. Putting the gnome-shell pkglibdir on
			 * LD_LIBRARY_PATH loads stock libshell-16.so and the client
			 * dies looking up shell_signals_pending_signals. */
			var gvc_path = GLib.Path.build_filename(GNOME_SHELL_PKGLIBDIR, "libgvc.so");
			var gvc = GLib.Module.open(gvc_path, GLib.ModuleFlags.BIND_LAZY);
			if (gvc != null) {
				gvc.make_resident();
			}
			GI.Repository.prepend_search_path(GNOME_SHELL_PKGLIBDIR);
			GI.Repository.prepend_search_path(MUTTER_TYPELIB_DIR);
			GI.Repository.prepend_search_path(TYPELIB_INSTALL_DIR);
			var typelib_dir = GLib.Environment.get_variable("GSR_TYPELIB_DIR") ?? "";
			if (typelib_dir.length > 0) {
				GI.Repository.prepend_search_path(typelib_dir);
			}
			/*
			 * Meta.RpcSubprocess peer (DING stdout / wait). Stock Meta GIR
			 * still returns Gio.Subprocess; GJS finds our methods by GType.
			 */
			GI.Repository.get_default().require("Gsr", "1.0", 0);
			GI.Repository.get_default().require("Clutter", "16", 0);
			GI.Repository.get_default().require("Shell", "16", 0);

			Gsr.Client.Rpc.register();
			global::Shell.Global.bind_display(global::Meta.get_display());
			/* Always off for now (temporary); later only with --disable-extensions. */
			Application.apply_extension_policy();
		}

		/**
		 * @param search_path GJS module search path for this context
		 * @return a context with {@code signals.js} already eval'd
		 */
		protected Gjs.Context open_context(string[] search_path)
		{
			var ctx = new Gjs.Context.with_search_path(search_path);
			var bytes = GLib.resources_lookup_data(
				"/org/gnome/shell-rpc/signals.js", GLib.ResourceLookupFlags.NONE);
			unowned uint8[] data = bytes.get_data();
			var buf = new GLib.StringBuilder.sized(data.length);
			buf.append_len((string) data, data.length);
			int wrap_status;
			ctx.eval(
				buf.str, buf.str.length,
				"resource:///org/gnome/shell-rpc/signals.js",
				out wrap_status);
			return ctx;
		}

		protected override int command_line(GLib.ApplicationCommandLine command_line)
		{
			string[] remaining;
			if (this.parse_options(command_line, "", out remaining) != 0) {
				return 1;
			}
			this.prepare_host();
			try {
				var result = GLib.Bus.get_sync(GLib.BusType.SESSION).call_sync(
					"org.freedesktop.DBus",
					"/org/freedesktop/DBus",
					"org.freedesktop.DBus",
					"RequestName",
					new GLib.Variant("(su)", "org.gnome.Shell",
						(uint) (GLib.BusNameOwnerFlags.ALLOW_REPLACEMENT
							| GLib.BusNameOwnerFlags.DO_NOT_QUEUE)),
					new GLib.VariantType("(u)"),
					GLib.DBusCallFlags.NONE,
					-1,
					null).get_child_value(0).get_uint32();
				if (result != 1 && result != 4) {
					GLib.warning("org.gnome.Shell not owned, reply %u", result);
				}
			} catch (GLib.Error e) {
				GLib.warning("org.gnome.Shell: %s", e.message);
			}

			var ctx = this.open_context({ "resource:///org/gnome/shell" });
			Gsr.Client.Rpc.call_value("Server-Bootstrap.begin_shell_startup");
			uint8 status = 0;
			ctx.eval_module_file("resource:///org/gnome/shell/ui/init.js", out status);
			ctx.eval_module_file("resource:///org/gnome/shell-rpc/restart.js", out status);
			return 0;
		}

		[CCode (cname = "g_memory_settings_backend_new")]
		private static extern GLib.SettingsBackend memory_settings_backend_new();

		/**
		 * Nest bisect: same stock key ExtensionManager reads
		 * ({@code org.gnome.shell disable-user-extensions}), on a memory
		 * backend so live-session dconf is not written. Stock has no
		 * {@code --disable-extensions} CLI.
		 */
		private static void apply_extension_policy()
		{
			var settings = new GLib.Settings.with_backend(
				"org.gnome.shell", Application.memory_settings_backend_new()
			);
			settings.set_boolean("disable-user-extensions", true);
			global::Shell.Global.get().host_install_settings(settings);
			GLib.message(
				"gnome-shell-rpc: disable-user-extensions "
				+ "(memory org.gnome.shell)"
			);
		}
	}
}
