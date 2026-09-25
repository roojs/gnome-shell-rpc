namespace LiveInterfaceGirGate
{
	public class Peer : GLib.Object, OLLMrpc.Live.Interface
	{
		public uint64 rpc_lid { get; set construct; default = 0; }
	}
}
