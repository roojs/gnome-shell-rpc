namespace GnomeShellRpc.Ui
{
	/** Params for workspace lookups. */
	public class WorkspaceParams : OLLMrpc.CallParam
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("WorkspaceParams", typeof(WorkspaceParams));
		}

		public int index { get; set; default = -1; }
	}
}
