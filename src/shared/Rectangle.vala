namespace Gsr.Shared
{
	/**
	 * Serializable frame rectangle ({@link Mtk.Rectangle} shape on the RPC).
	 *
	 * Used by both {@link Gsr.Shared.Window} snapshots and
	 * {@link Gsr.FakeShell.Window} proxies.
	 *
	 * == Example ==
	 *
	 * {{{
	 * OLLMrpc.Bin.register("Rectangle", typeof(Gsr.Shared.Rectangle));
	 * var r = new Gsr.Shared.Rectangle() {
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
