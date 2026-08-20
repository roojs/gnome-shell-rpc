namespace GnomeShellRpc.Shared
{
	/**
	 * Serializable frame rectangle ({@link Mtk.Rectangle} shape on the RPC).
	 *
	 * Used by both {@link GnomeShellRpc.Ui.Window} snapshots and
	 * {@link GnomeShellRpc.Remote.Window} proxies.
	 *
	 * == Example ==
	 *
	 * {{{
	 * OLLMrpc.Bin.register("Rectangle", typeof(GnomeShellRpc.Shared.Rectangle));
	 * var r = new GnomeShellRpc.Shared.Rectangle() {
	 *     x = 10, y = 20, width = 800, height = 600,
	 * };
	 * }}}
	 */
	public class Rectangle : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Rectangle", typeof(Rectangle));
		}

		public int x { get; set; default = 0; }
		public int y { get; set; default = 0; }
		public int width { get; set; default = 0; }
		public int height { get; set; default = 0; }
	}
}
