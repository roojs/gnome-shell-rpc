namespace GnomeShellRpc.Ui
{
	/** Workspace snapshot for RPC clients. */
	public class Workspace : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Workspace", typeof(Workspace));
		}

		public int id { get; set; default = 0; }
		public int index { get; set; default = 0; }
		public int window_count { get; set; default = 0; }
	}
}
