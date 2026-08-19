namespace GnomeShellRpc.Ui
{
	/**
	 * Window as the remote client sees it (read-only in plan 0.2).
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
		public Rectangle? frame_rect { get; set; default = null; }
	}
}
