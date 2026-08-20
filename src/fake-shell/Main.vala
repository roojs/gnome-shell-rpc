namespace GnomeShellRpc.FakeShell
{
	/**
	 * Process entry for the throwaway GTK client.
	 *
	 * == Example ==
	 *
	 * {{{
	 * ./build/src/fake-shell --debug
	 * }}}
	 */
	public static int main(string[] args)
	{
		owned string[] filtered = GnomeShellRpc.Debug.parse_args(args);
		GnomeShellRpc.Debug.install_log_handler("fake-shell");
		unowned string[] argv = filtered;
		return new Application().run(argv);
	}
}
