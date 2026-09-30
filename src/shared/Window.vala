namespace GnomeShellRpc.Ui
{
	/**
	 * One window in the list the compositor sends to the shell client.
	 *
	 * gnome-shell normally runs inside mutter and reads each window directly.
	 * Here the shell is a separate process, so it gets a simple table of windows
	 * over RPC. Each column is something gnome-shell already reads when it loops
	 * windows (title, class, geometry, flags, {@link window_type}, …). Changing
	 * a window uses other APIs; this record is list-only.
	 *
	 * == Example ==
	 *
	 * {{{
	 * GnomeShellRpc.Ui.Window.rpc_register();
	 * var snap = new GnomeShellRpc.Ui.Window() {
	 *     id = 3,
	 *     title = "gedit",
	 * };
	 * }}}
	 */
	public class Window : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Window", typeof(Window));
		}

		public int id { get; set; default = 0; }
		public string title { get; set; default = ""; }
		public string wm_class { get; set; default = ""; }
		/**
		 * {@link Meta.WindowType} as int (e.g. 0 = NORMAL, 3 = DIALOG); value when
		 * the list was built.
		 *
		 * Needed by {@code Shell.App.activate_window}: it inspects transients with
		 * {@code w.window_type} and only keeps NORMAL/DIALOG candidates — same as
		 * stock gnome-shell. Windows from {@code list_all_windows} get type from
		 * this row instead of a separate compositor query per window.
		 */
		public int window_type { get; set; default = 0; }
		public bool minimized { get; set; default = false; }
		public bool maximized { get; set; default = false; }
		public Shared.Rectangle frame_rect { get; set; default = new Shared.Rectangle(); }
	}
}
