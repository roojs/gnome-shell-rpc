namespace GnomeShellRpc.Ui
{
	/**
	 * Window as the remote client sees it (snapshot fields only).
	 *
	 * Mutating methods live on {@link Display} (`minimize_window`, …).
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
		public bool minimized { get; set; default = false; }
		public bool maximized { get; set; default = false; }
		public Shared.Rectangle frame_rect { get; set; default = new Shared.Rectangle(); }
	}
}
