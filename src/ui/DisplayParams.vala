namespace GnomeShellRpc.Ui
{
	/** Params for {@link Display} RPC methods. */
	public class DisplayParams : OLLMrpc.CallParam
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("DisplayParams", typeof(DisplayParams));
		}
	}
}
