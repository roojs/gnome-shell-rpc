namespace GiRpcSmoke
{
	/** Result row for {@code RPC-GiRpcSmoke.ping}. */
	public class PingResult : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("PingResult", typeof(PingResult));
		}

		public string reply { get; set; default = ""; }
	}
}
