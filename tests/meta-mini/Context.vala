namespace Meta
{
	/**
	 * Mini stand-in so shared {@link Gsr.Client.Rpc} can register.
	 */
	public class Context : GLib.Object, OLLMrpc.Live.Interface
	{
		public uint64 rpc_lid { get; set construct; default = 0; }

		public static void register()
		{
			OLLMrpc.Bin.register("Meta-Context", typeof(Context));
		}

		public Backend get_backend()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Meta-Context.get_backend", this);
			var backend = new Backend();
			backend.rpc_lid = response.args.get(0).get_uint64();
			return backend;
		}
	}
}
