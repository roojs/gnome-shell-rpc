namespace GiRpcSmoke
{
	/** Params for {@code GiRpcSmoke.ping}. */
	public class PingParams : OLLMrpc.CallParam
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("PingParams", typeof(PingParams));
		}

		public string msg { get; set; default = ""; }
	}
}
