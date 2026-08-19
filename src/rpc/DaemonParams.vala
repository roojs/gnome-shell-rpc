namespace GnomeShellRpc.Rpc
{
	/** Params for {@code RPC-Daemon.hello}. */
	public class DaemonParams : OLLMrpc.CallParam
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("DaemonParams", typeof(DaemonParams));
		}

		public int protocol { get; set; default = 0; }
		public string client { get; set; default = ""; }
	}
}
