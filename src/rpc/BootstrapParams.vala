namespace GnomeShellRpc.Rpc
{
	/** Params for {@code RPC-Bootstrap.get_display}. */
	public class BootstrapParams : OLLMrpc.CallParam
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("BootstrapParams", typeof(BootstrapParams));
		}
	}
}
