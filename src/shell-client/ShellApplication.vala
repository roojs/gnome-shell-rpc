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
		private const string SHELL_RESOURCE_PREFIX = "resource:///org/gnome/shell/";

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
			var override_dir = GLib.Environment.get_variable("GI_RPC_JS_OVERRIDE_DIR");
			override_dir = override_dir != null ? override_dir : "";
			var vendor_dir = GLib.Environment.get_variable("GI_RPC_JS_VENDOR_DIR");
			vendor_dir = vendor_dir != null ? vendor_dir : "";
			if (override_dir.length > 0 || vendor_dir.length > 0) {
				this.register_js_overrides(ctx, vendor_dir, override_dir);
			}
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
		 * Debug: map resource:///org/gnome/shell/… modules to disk files.
		 * Walks the embedded gresource tree; {@code override_dir} wins over
		 * {@code vendor_dir} for each bundled {@code .js} path.
		 *
		 * @param ctx GJS context
		 * @param vendor_dir upstream JS tree (e.g. vendor/gnome-shell/js)
		 * @param override_dir sparse edits mirroring org/gnome/shell paths
		 */
		private void register_js_overrides(
			Gjs.Context ctx,
			string vendor_dir,
			string override_dir
		)
		{
			var modules = new Gee.HashMap<string, string>();
			this.collect_js_resource_modules(vendor_dir, override_dir, modules);
			if (modules.size == 0) {
				return;
			}
			foreach (var rel in modules.keys) {
				var resource_uri = SHELL_RESOURCE_PREFIX + rel;
				var file_uri = modules.get(rel);
				try {
					ctx.register_module(resource_uri, file_uri);
					GLib.debug("js module %s <- %s", resource_uri, file_uri);
				} catch (GLib.Error e) {
					GLib.warning("js module register failed %s <- %s: %s",
						resource_uri, file_uri, e.message);
				}
			}
		}

		/**
		 * Collect bundled {@code .js} paths and matching disk files.
		 *
		 * @param vendor_dir upstream JS tree
		 * @param override_dir sparse override tree
		 * @param modules relative path → file URI; override wins over vendor
		 */
		private void collect_js_resource_modules(
			string vendor_dir,
			string override_dir,
			Gee.HashMap<string, string> modules
		)
		{
			var resource = shell_js_resources_get_resource();
			var root = "/org/gnome/shell";
			var prefix = root + "/";
			string[] stack = { root };

			while (stack.length > 0) {
				var dir_path = stack[stack.length - 1];
				stack.length -= 1;

				string[] children;
				try {
					children = resource.enumerate_children(
						dir_path,
						GLib.ResourceLookupFlags.NONE
					);
				} catch (GLib.Error e) {
					GLib.warning("js module scan: cannot read %s: %s",
						dir_path, e.message);
					continue;
				}

				foreach (var entry in children) {
					var name = entry.strip();
					if (name.length == 0) {
						continue;
					}
					if (name.has_prefix("/")) {
						name = name.substring(1);
					}
					if (name.has_suffix("/")) {
						name = name.substring(0, name.length - 1);
					}
					var child = GLib.Path.build_filename(dir_path, name);
					if (!name.has_suffix(".js")) {
						stack += child;
						continue;
					}
					var rel = child.substring(prefix.length);
					var file_path = "";
					if (override_dir.length > 0) {
						var override_path = GLib.Path.build_filename(
							override_dir, rel);
						if (GLib.FileUtils.test(override_path, GLib.FileTest.EXISTS)) {
							file_path = override_path;
						}
					}
					if (file_path.length == 0 && vendor_dir.length > 0) {
						var vendor_path = GLib.Path.build_filename(
							vendor_dir, rel);
						if (GLib.FileUtils.test(vendor_path, GLib.FileTest.EXISTS)) {
							file_path = vendor_path;
						}
					}
					if (file_path.length == 0) {
						continue;
					}
					modules.set(rel, GLib.File.new_for_path(file_path).get_uri());
				}
			}
		}
	}

	int main(string[] args)
	{
		return new Application().run(args);
	}
}
