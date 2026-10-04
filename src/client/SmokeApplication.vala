namespace Gsr.Client
{
	/**
	 * Smoke and debug host. Same RPC register, display bind, and signals
	 * wrap as {@link Application}, then evals the given script.
	 *
	 * == Example ==
	 *
	 * {{{
	 * ./build/src/gsr-smoke --debug tests/gjs-embed/key-smoke.js
	 * }}}
	 */
	public class SmokeApplication : Application
	{
		protected override int command_line(GLib.ApplicationCommandLine command_line)
		{
			string[] remaining;
			if (this.parse_options(command_line, "SCRIPT.js", out remaining) != 0) {
				return 1;
			}
			if (remaining.length < 2) {
				command_line.printerr("usage: gsr-smoke [--debug] SCRIPT.js\n");
				return 1;
			}

			var override_dir = GLib.Environment.get_variable("GI_RPC_JS_OVERRIDE_DIR") ?? "";
			if (override_dir.length > 0) {
				this.install_js_override_overlay(override_dir);
			}
			this.prepare_host();

			var js_dir = GLib.Environment.get_variable("GNOME_SHELL_JS_DIR") ?? "";
			var script = this.resolve_script(remaining, js_dir);
			string[] search_path = {};
			if (js_dir.length > 0) {
				search_path += js_dir;
			}
			search_path += "resource:///org/gnome/shell";
			var embed_dir = GLib.Environment.get_variable("GI_RPC_GJS_EMBED_DIR") ?? "";
			if (embed_dir.length > 0) {
				search_path += embed_dir;
			}
			if (!script.has_prefix("resource://")) {
				search_path += GLib.Path.get_dirname(script);
			}
			search_path += ".";

			var ctx = this.open_context(search_path);
			var booting_shell = script == "resource:///org/gnome/shell/ui/init.js"
				|| script.has_suffix("/ui/init.js");
			if (booting_shell) {
				this.eval_preload(
					ctx, embed_dir,
					"GI_RPC_REGISTER_CLASS_TRACE",
					"register-class-trace-preload.js");
				this.eval_preload(
					ctx, embed_dir,
					"GI_RPC_LAUNCH_PROBE",
					"app-launch-click-probe-preload.js");
				Gsr.Client.Rpc.call_value("Server-Bootstrap.begin_shell_startup");
			}
			uint8 module_status = 0;
			int status = 0;
			if (script.has_prefix("resource://")
				|| script.contains("/ui/init.js")
				|| script.contains("/gjs-embed/")) {
				ctx.eval_module_file(script, out module_status);
				status = module_status;
			} else {
				ctx.eval_file(script, out status);
			}
			if (booting_shell) {
				ctx.eval_module_file(
					"resource:///org/gnome/shell-rpc/restart.js",
					out module_status);
			}
			return status;
		}

		/**
		 * Eval {@code filename} from {@code embed_dir} when {@code env_name}
		 * is set. {@code 0} and {@code false} mean off.
		 *
		 * @param ctx context that will eval the shell or the smoke
		 * @param embed_dir directory named by {@code GI_RPC_GJS_EMBED_DIR}
		 * @param env_name probe switch
		 * @param filename preload module inside {@code embed_dir}
		 */
		private void eval_preload(
			Gjs.Context ctx,
			string embed_dir,
			string env_name,
			string filename)
		{
			var value = GLib.Environment.get_variable(env_name) ?? "";
			if (value.length == 0 || value == "0" || value == "false") {
				return;
			}
			if (embed_dir.length == 0) {
				GLib.error("%s requires GI_RPC_GJS_EMBED_DIR", env_name);
			}
			uint8 status = 0;
			ctx.eval_module_file(
				GLib.Path.build_filename(embed_dir, filename),
				out status);
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
			return "resource:///org/gnome/shell/ui/init.js";
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
						var dest_dir = GLib.File.new_for_path(
							GLib.Path.get_dirname(dest)
						);
						try {
							dest_dir.make_directory_with_parents(null);
						} catch (GLib.Error mkdir_err) {
							if (!(mkdir_err is GLib.IOError.EXISTS)) {
								throw mkdir_err;
							}
						}
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
			/* Static JS resources stay on GLib's lazy list until the first
			 * lookup, and that lookup prepends them. Registering first
			 * lets the stock bundle shadow this overlay. Flush, then
			 * register, so the overlay is the one lookup finds. */

			GLib.resources_lookup_data("/org/gnome/shell/ui/init.js", GLib.ResourceLookupFlags.NONE);

			GLib.resources_register(overlay);
			GLib.debug("js override overlay %d files from %s",
				rel_paths.length, override_dir);
		}
	}
}
