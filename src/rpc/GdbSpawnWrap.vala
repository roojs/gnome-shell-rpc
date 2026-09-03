namespace GnomeShellRpc.Rpc
{
	/**
	 * Optional gdb/gdbserver wrapper for nested {@code gnome-shell-rpc} spawn.
	 *
	 * Built only when {@code -Drpc_gdb_spawn=true}. At runtime, no-op unless
	 * {@code GI_META_GDB} is set.
	 *
	 * Modes: {@code batch} (auto backtrace on SIGABRT/SIGSEGV), {@code server} /
	 * {@code wait} (gdbserver on {@code GI_META_GDB_PORT}, default 9234),
	 * {@code 1} / {@code interactive} ({@code gdb --args}). Extra {@code -ex}
	 * commands: {@code GI_META_GDB_EX} (semicolon-separated).
	 */
	public class GdbSpawnWrap : GLib.Object
	{
		/**
		 * Prepend gdb/gdbserver when {@code GI_META_GDB} is set; else return
		 * {@code argv} unchanged.
		 */
		public static string[] maybe_wrap_argv(string[] argv)
		{
			var mode = GLib.Environment.get_variable("GI_META_GDB");
			if (mode == null || mode.length == 0) {
				return argv;
			}

			var gdb = GLib.Environment.get_variable("GI_META_GDB_BIN");
			if (gdb == null || gdb.length == 0) {
				gdb = "gdb";
			}
			var gdbserver = GLib.Environment.get_variable("GI_META_GDBSERVER_BIN");
			if (gdbserver == null || gdbserver.length == 0) {
				gdbserver = "gdbserver";
			}

			if (mode == "server" || mode == "wait") {
				var port = GLib.Environment.get_variable("GI_META_GDB_PORT");
				if (port == null || port.length == 0) {
					port = "9234";
				}
				GLib.warning(
					"GI_META_GDB=%s: attach with gdb %s then target extended-remote localhost:%s",
					mode, argv[0], port
				);
				return GdbSpawnWrap.concat_argv({
					gdbserver, "localhost:%s".printf(port), "--args",
				}, argv);
			}

			string[] prefix = { gdb };
			if (mode == "batch") {
				prefix += "-batch";
			}
			prefix += "-ex";
			prefix += "set pagination off";
			prefix += "-ex";
			prefix += "set confirm off";
			prefix += "-ex";
			prefix += "handle SIGPIPE nostop noprint pass";
			if (mode == "batch") {
				prefix += "-ex";
				prefix += "catch signal SIGABRT";
				prefix += "-ex";
				prefix += "catch signal SIGSEGV";
			}

			var extra = GLib.Environment.get_variable("GI_META_GDB_EX");
			if (extra != null && extra.length > 0) {
				foreach (var cmd in extra.split(";")) {
					var trimmed = cmd.strip();
					if (trimmed.length > 0) {
						prefix += "-ex";
						prefix += trimmed;
					}
				}
			}

			if (mode == "batch") {
				prefix += "-ex";
				prefix += "run";
				prefix += "-ex";
				prefix += "thread apply all bt full";
				prefix += "-ex";
				prefix += "quit";
			}
			prefix += "--args";
			return GdbSpawnWrap.concat_argv(prefix, argv);
		}

		private static string[] concat_argv(string[] head, string[] tail)
		{
			var merged = head;
			foreach (var arg in tail) {
				merged += arg;
			}
			return merged;
		}
	}
}
