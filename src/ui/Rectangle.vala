namespace GnomeShellRpc.Ui
{
	/**
	 * Serializable frame rectangle ({@link Mtk.Rectangle} on the wire).
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
