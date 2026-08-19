namespace GnomeShellRpc
{
	/**
	 * ''--debug'' / ''--debug-critical'' handling — stderr format matches
	 * {@link OLLMchat.ApplicationInterface.debug_log} (without libollmchat).
	 *
	 * Strip our flags from ''argv'' before passing the rest to mutter or other
	 * parsers. Install {@link install_log_handler} after {@link parse_args}.
	 */
	public class Debug
	{
		public static bool debug_on = false;
		public static bool debug_critical_enabled = false;

		private static bool log_in_progress = false;
		private static string log_app_id = "";
		private static GLib.FileStream? log_file = null;

		/**
		 * Scan ''args'' for debug flags and return argv with those entries removed.
		 */
		public static owned string[] parse_args(string[] args)
		{
			Debug.debug_on = false;
			Debug.debug_critical_enabled = false;
			var out_args = new Gee.ArrayList<string>();
			for (var i = 0; i < args.length; i++) {
				var arg = args[i];
				if (arg == "--debug" || arg == "-d") {
					Debug.debug_on = true;
					continue;
				}
				if (arg == "--debug-critical") {
					Debug.debug_critical_enabled = true;
					continue;
				}
				out_args.add(arg);
			}
			return out_args.to_array();
		}

		/**
		 * Route GLib log through stderr when {@link debug_on} or on critical.
		 *
		 * @param app_id label for the debug log file under ~/.cache/ollmchat/
		 */
		public static void install_log_handler(string app_id)
		{
			Debug.log_app_id = app_id;
			GLib.Log.set_default_handler((dom, lvl, msg) => {
				Debug.log(dom, lvl, msg);
			});
		}

		private static void log(
			string? in_domain,
			GLib.LogLevelFlags level,
			string message
		)
		{
			if (Debug.log_in_progress) {
				return;
			}

			var timestamp = (new GLib.DateTime.now_local()).format("%H:%M:%S.%f");

			var should_output = Debug.debug_on
				|| (level & GLib.LogLevelFlags.LEVEL_CRITICAL) != 0;
			if (should_output) {
				GLib.stderr.printf(
					timestamp + ": " + level.to_string() + " : "
						+ (in_domain != null ? in_domain : "") + " : "
						+ message + "\n"
				);
			}

			if ((level & GLib.LogLevelFlags.LEVEL_CRITICAL) != 0
				&& Debug.debug_critical_enabled) {
				GLib.error("Critical warning: [%s] %s",
					in_domain != null ? in_domain : "", message);
			}

			Debug.log_in_progress = true;

			if (Debug.log_file == null && Debug.log_app_id != "") {
				var log_dir = GLib.Path.build_filename(
					GLib.Environment.get_home_dir(),
					".cache",
					"ollmchat"
				);
				var log_file_path = GLib.Path.build_filename(
					log_dir,
					Debug.log_app_id + ".debug.log"
				);
				if (!GLib.FileUtils.test(log_dir, GLib.FileTest.IS_DIR)) {
					GLib.DirUtils.create_with_parents(log_dir, 0755);
				}
				Debug.log_file = GLib.FileStream.open(log_file_path, "w");
			}

			if (Debug.log_file != null) {
				Debug.log_file.puts(
					timestamp + ": " + level.to_string() + " : " + message + "\n"
				);
				Debug.log_file.flush();
			}

			Debug.log_in_progress = false;
		}
	}
}
