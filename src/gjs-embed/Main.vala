namespace GnomeShellRpc.GjsEmbed
{
	/**
	 * Process entry: construct {@link Gjs.Context} and eval a script file.
	 *
	 * argv after {@code --debug} is the script path.
	 *
	 * == Example ==
	 *
	 * {{{
	 * ./build/src/gjs-embed --debug src/gjs-embed/smoke.js
	 * }}}
	 */
	public static int main(string[] args)
	{
		owned string[] argv = GnomeShellRpc.Debug.parse_args(args);
		GnomeShellRpc.Debug.install_log_handler("gjs-embed");
		if (argv.length < 2) {
			GLib.printerr("usage: gjs-embed [--debug] SCRIPT.js\n");
			return 1;
		}

		var script = argv[1];
		string[] search_path = {};
		search_path += GLib.Path.get_dirname(script);
		search_path += ".";
		GLib.debug("script %s", script);

		var ctx = new Gjs.Context.with_search_path(search_path);

		var status = 0;
		var ok = false;
		try {
			ok = ctx.eval_file(script, out status);
		} catch (GLib.Error e) {
			GLib.printerr("%s\n", e.message);
			return 1;
		}
		if (!ok) {
			return 1;
		}
		return status;
	}
}
