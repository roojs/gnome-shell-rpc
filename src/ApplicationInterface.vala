namespace GnomeShellRpc
{
	// Static storage for debug logging
	private static GLib.FileStream? debug_log_file = null;
	private static bool debug_log_in_progress = false;

	/**
	 * Enable debug output (show all log messages).
	 * Set to true to see all log messages, false to only see critical warnings.
	 */
	public static bool debug_on = false;

	/**
	 * Enable treating critical warnings as errors (abort on critical warnings).
	 * Set to true to cause the program to abort on critical warnings.
	 */
	public static bool debug_critical_enabled = false;

	/**
	 * Shared surface for gnome-shell-rpc applications.
	 *
	 * Apps implement this interface, parse {@code --debug} via
	 * {@link GLib.OptionEntry}, set {@link GnomeShellRpc.debug_on}, and install
	 * a log handler that calls {@link debug_log}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * public class Application : GLib.Application, ApplicationInterface
	 * {
	 *     private static bool opt_debug = false;
	 *
	 *     protected override int command_line(GLib.ApplicationCommandLine cl)
	 *     {
	 *         // … OptionContext.parse …
	 *         GnomeShellRpc.debug_on = opt_debug;
	 *         GLib.Log.set_default_handler((dom, lvl, msg) => {
	 *             ApplicationInterface.debug_log(
	 *                 this.get_application_id(), dom, lvl, msg);
	 *         });
	 *         return 0;
	 *     }
	 * }
	 * }}}
	 */
	public interface ApplicationInterface : GLib.Object
	{
		/**
		 * Checks if help flag (--help or -h) is present in command-line arguments.
		 *
		 * @param args Command-line arguments array
		 * @return true if help flag is found, false otherwise
		 */
		public bool check_help_arg(string[] args)
		{
			foreach (var arg in args) {
				if (arg == "--help" || arg == "-h") {
					return true;
				}
			}
			return false;
		}

		/**
		 * Returns custom help text for this application.
		 * If 'help' property is set, outputs it (with {ARG} replaced) followed by
		 * auto-generated options from GLib's OptionContext.
		 *
		 * @param help_text Custom help text (may contain {ARG} placeholder)
		 * @param program_name The program name (args[0]) to use in help text
		 * @param opt_context OptionContext to extract options from
		 * @return Custom help text string, or null if help_text is empty
		 */
		public string? get_help_text(
			string help_text,
			string program_name,
			GLib.OptionContext opt_context
		)
		{
			if (help_text == "") {
				return null;
			}

			// Extract only the options section (skip usage line)
			// Find the first section header (e.g., "Help Options:" or "Application Options:")
			var lines = opt_context.get_help(false, null).split("\n");
			string options_text = "";
			bool found_options = false;
			foreach (string line in lines) {
				if (!found_options && line.has_suffix("Options:")) {
					found_options = true;
				}
				if (found_options) {
					options_text += "\n" + line;
				}
			}

			// Output custom help (without options) + auto-generated options
			return help_text.replace("{ARG}", program_name) + "\n" + options_text;
		}

		/**
		 * Debug logging function that writes to
		 * ~/.cache/gnome-shell-rpc/{app_id}.debug.log
		 * Also writes to stderr for immediate console output.
		 *
		 * @param app_id The application ID to use for the log file name
		 * @param in_domain The log domain (can be null)
		 * @param level The log level
		 * @param message The log message
		 */
		protected static void debug_log(
			string app_id,
			string? in_domain,
			GLib.LogLevelFlags level,
			string message
		)
		{
			// Prevent recursive logging if an error occurs during logging
			if (debug_log_in_progress) {
				return;
			}

			// Generate timestamp for logging
			var timestamp = (new GLib.DateTime.now_local()).format("%H:%M:%S.%f");

			// Only output if debug is enabled, or if it's a critical warning
			bool should_output = debug_on
				|| (level & GLib.LogLevelFlags.LEVEL_CRITICAL) != 0;

			if (should_output) {
				// Write to stderr for immediate console output
				GLib.stderr.printf(
					timestamp + ": " + level.to_string() + " : "
						+ (in_domain == null ? "" : in_domain) + " : "
						+ message + "\n"
				);
			}

			// Handle critical errors if debug_critical is enabled
			if ((level & GLib.LogLevelFlags.LEVEL_CRITICAL) != 0
				&& debug_critical_enabled) {
				GLib.error(
					"Critical warning: [" + (in_domain ?? "") + "] " + message
				);
			}
			// we carry on even if debug is off (so we can log the debug stuff)
			debug_log_in_progress = true;

			// Open log file lazily on first use (using FileStream to avoid GIO initialization deadlock)
			if (debug_log_file == null) {
				var log_dir = GLib.Path.build_filename(
					GLib.Environment.get_home_dir(),
					".cache",
					"gnome-shell-rpc"
				);
				var log_file_path = GLib.Path.build_filename(
					log_dir,
					app_id + ".debug.log"
				);

				if (!GLib.FileUtils.test(log_dir, GLib.FileTest.IS_DIR)) {
					GLib.DirUtils.create_with_parents(log_dir, 0755);
				}

				// Open file in write mode (truncates existing file) using FileStream (doesn't require GIO initialization)
				debug_log_file = GLib.FileStream.open(log_file_path, "w");
				if (debug_log_file == null) {
					GLib.stderr.printf(
						"ERROR: FAILED TO OPEN DEBUG LOG FILE: Unable to open file stream\n"
					);
					debug_log_in_progress = false;
					return;
				}
			}

			// Write to log file
			try {
				if (debug_log_file != null) {
					debug_log_file.puts(
						timestamp + ": " + level.to_string() + " : "
							+ message + "\n"
					);
					debug_log_file.flush();
				}
			} catch (GLib.Error e) {
				GLib.stderr.printf(
					"ERROR: FAILED TO WRITE TO DEBUG LOG FILE: " + e.message + "\n"
				);
			}
			debug_log_in_progress = false;
		}
	}
}
