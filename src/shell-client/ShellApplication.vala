/**
 * gnome-shell-rpc thin host — no libshell (0.7.7).
 *
 * {@code Runtime.register()} → {@link Shell.Global.bind_display} → own
 * {@link Gjs.Context} → eval {@code init.js} (default) or SCRIPT.js.
 */
namespace GnomeShellRpc.ShellClient
{
	public class Application : GLib.Application, GnomeShellRpc.ApplicationInterface
	{
		private const string APPLICATION_ID = "org.gnome.ShellRpc";
		private const string INIT_MODULE = "resource:///org/gnome/shell/ui/init.js";

		private static bool opt_debug = false;
		private static bool opt_debug_critical = false;

		private const GLib.OptionEntry[] options = {
			{ "debug", 'd', 0, GLib.OptionArg.NONE, ref opt_debug,
				"Enable debug output", null },
			{ "debug-critical", 0, 0, GLib.OptionArg.NONE, ref opt_debug_critical,
				"Treat critical warnings as errors", null },
			{ null }
		};

		[CCode (cname = "shell_js_resources_get_resource")]
		private static extern GLib.Resource shell_js_resources_get_resource();

		public Application()
		{
			GLib.Object(
				application_id: APPLICATION_ID,
				flags: GLib.ApplicationFlags.HANDLES_COMMAND_LINE
					| GLib.ApplicationFlags.NON_UNIQUE
			);

			GLib.Log.set_default_handler((dom, lvl, msg) => {
				GnomeShellRpc.ApplicationInterface.debug_log(
					this.get_application_id(), dom, lvl, msg
				);
			});
		}

		protected override int command_line(GLib.ApplicationCommandLine command_line)
		{
			Application.opt_debug = false;
			Application.opt_debug_critical = false;

			var args = command_line.get_arguments();
			var opt_context = new GLib.OptionContext("[SCRIPT.js]");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(Application.options, null);

			unowned string[] remaining = args;
			try {
				opt_context.parse(ref remaining);
			} catch (GLib.OptionError e) {
				command_line.printerr("error: %s\n", e.message);
				return 1;
			}

			GnomeShellRpc.debug_on = Application.opt_debug;
			GnomeShellRpc.debug_critical_enabled =
				Application.opt_debug_critical;

			prepend_typelib_paths();
			GLib.resources_register(shell_js_resources_get_resource());

			var override_dir = GLib.Environment.get_variable("GI_RPC_JS_OVERRIDE_DIR");
			override_dir = override_dir != null ? override_dir : "";
			if (override_dir.length > 0) {
				this.install_js_override_overlay(override_dir);
			}

			GnomeShellRpc.GiStub.Runtime.register();
			Shell.Global.bind_display(Meta.get_display());

			var js_dir = GLib.Environment.get_variable("GNOME_SHELL_JS_DIR") ?? "";
			var script = resolve_script(remaining, js_dir);
			string[] search_path = {};
			if (js_dir.length > 0) {
				search_path += js_dir;
				GLib.debug("gnome-shell JS search-path %s", js_dir);
			}
			search_path += "resource:///org/gnome/shell";
			var embed_dir = GLib.Environment.get_variable("GI_RPC_GJS_EMBED_DIR") ?? "";
			if (embed_dir.length > 0) {
				search_path += embed_dir;
				GLib.debug("gjs-embed search-path %s", embed_dir);
			}
			if (!script.has_prefix("resource://")) {
				search_path += GLib.Path.get_dirname(script);
			}
			search_path += ".";

			GLib.debug("shell script %s", script);
			var ctx = new Gjs.Context.with_search_path(search_path);
			var status = 0;
			var ok = false;
			try {
				var trace = GLib.Environment.get_variable("GI_RPC_REGISTER_CLASS_TRACE") ?? "";
				if (trace.length > 0 && trace != "0" && trace != "false"
						&& (script == INIT_MODULE || script.has_suffix("/ui/init.js"))) {
					if (embed_dir.length == 0) {
						command_line.printerr(
							"GI_RPC_REGISTER_CLASS_TRACE requires GI_RPC_GJS_EMBED_DIR\n"
						);
						return 1;
					}
					var preload = GLib.Path.build_filename(
						embed_dir, "register-class-trace-preload.js");
					uint8 preload_status = 0;
					ok = ctx.eval_module_file(preload, out preload_status);
					status = preload_status;
					if (!ok) {
						return 1;
					}
				}
				if (script.has_prefix("resource://")
					|| script.contains("/ui/init.js")
					|| script.contains("/gjs-embed/")) {
					uint8 module_status = 0;
					ok = ctx.eval_module_file(script, out module_status);
					status = module_status;
				} else {
					ok = ctx.eval_file(script, out status);
				}
			} catch (GLib.Error e) {
				command_line.printerr("%s\n", e.message);
				return 1;
			}
			if (!ok) {
				return 1;
			}
			return status;
		}

		private void prepend_typelib_paths()
		{
			var typelib_dir = GLib.Environment.get_variable( "GI_RPC_SMOKE_TYPELIB_DIR") ?? "";
			if (typelib_dir.length > 0) {
				GI.Repository.prepend_search_path(typelib_dir);
				GLib.debug("typelib prepend %s", typelib_dir);
			}
		}

		private string resolve_script(unowned string[] remaining, string js_dir)
		{
			if (remaining.length >= 2) {
				return remaining[1];
			}
			if (js_dir.length > 0) {
				var init_path = GLib.Path.build_filename(js_dir, "ui", "init.js");
				if (GLib.FileUtils.test(init_path, GLib.FileTest.EXISTS)) {
					return init_path;
				}
			}
			return INIT_MODULE;
		}

		/**
		 * Debug: overlay bundled {@code resource:///org/gnome/shell/…} paths with
		 * disk files from {@code override_dir}. Later {@link GLib.Resource}
		 * registrations win on lookup — JS pulls them during normal import.
		 *
		 * @param override_dir sparse edits mirroring org/gnome/shell paths
		 */
		private void install_js_override_overlay(string override_dir)
		{
			string temp;
			try {
				temp = GLib.DirUtils.make_tmp("gnome-shell-rpc-js-XXXXXX");
			} catch (GLib.Error e) {
				GLib.warning("js override overlay: temp dir failed: %s", e.message);
				return;
			}
			var staging = GLib.Path.build_filename(temp, "staging");
			try {
				GLib.File.new_for_path(staging).make_directory_with_parents(null);
			} catch (GLib.Error e) {
				GLib.warning("js override overlay: mkdir failed: %s", e.message);
				return;
			}

			var root = GLib.File.new_for_path(override_dir);
			string[] rel_paths = {};
			GLib.File[] stack = { root };

			while (stack.length > 0) {
				var dir = stack[stack.length - 1];
				stack.length -= 1;

				GLib.FileEnumerator enumerator;
				try {
					enumerator = dir.enumerate_children(
						"standard::name,standard::type",
						GLib.FileQueryInfoFlags.NONE
					);
				} catch (GLib.Error e) {
					GLib.warning("js override overlay: cannot read %s: %s",
						dir.get_path(), e.message);
					continue;
				}

				GLib.FileInfo info;
				while ((info = enumerator.next_file()) != null) {
					var child = dir.get_child(info.get_name());
					if (info.get_file_type() == GLib.FileType.DIRECTORY) {
						stack += child;
						continue;
					}
					if (!info.get_name().has_suffix(".js")) {
						continue;
					}
					var rel = root.get_relative_path(child);
					if (rel == null) {
						continue;
					}
					rel = rel.replace("\\", "/");
					var dest = GLib.Path.build_filename(staging, rel);
					try {
						GLib.File.new_for_path(
							GLib.Path.get_dirname(dest)
						).make_directory_with_parents(null);
						child.copy(
							GLib.File.new_for_path(dest),
							GLib.FileCopyFlags.OVERWRITE,
							null
						);
					} catch (GLib.Error e) {
						GLib.warning("js override overlay: copy failed %s: %s",
							rel, e.message);
						continue;
					}
					rel_paths += rel;
				}
			}

			if (rel_paths.length == 0) {
				return;
			}

			var xml_path = GLib.Path.build_filename(temp, "overlay.gresource.xml");
			var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
				+ "<gresources>\n"
				+ "  <gresource prefix=\"/org/gnome/shell\">\n";
			foreach (var rel in rel_paths) {
				xml += "    <file>" + rel + "</file>\n";
			}
			xml += "  </gresource>\n</gresources>\n";
			GLib.FileUtils.set_contents(xml_path, xml);

			var gresource_path = GLib.Path.build_filename(temp, "overlay.gresource");
			string[] argv = {
				"glib-compile-resources",
				"--target=" + gresource_path,
				"--sourcedir=" + staging,
				xml_path,
			};
			string? spawn_out = null;
			string? spawn_err = null;
			int spawn_status = 0;
			try {
				GLib.Process.spawn_sync(
					null,
					argv,
					null,
					GLib.SpawnFlags.SEARCH_PATH,
					null,
					out spawn_out,
					out spawn_err,
					out spawn_status
				);
			} catch (GLib.Error e) {
				GLib.warning("js override overlay: compile failed: %s", e.message);
				return;
			}
			if (spawn_status != 0) {
				GLib.warning("js override overlay: glib-compile-resources exit %d",
					spawn_status);
				return;
			}

			GLib.Resource overlay;
			try {
				overlay = GLib.Resource.load(gresource_path);
			} catch (GLib.Error e) {
				GLib.warning("js override overlay: load failed: %s", e.message);
				return;
			}
			GLib.resources_register(overlay);
			GLib.debug("js override overlay %d files from %s",
				rel_paths.length, override_dir);
		}
	}

	int main(string[] args)
	{
		return new Application().run(args);
	}
}
