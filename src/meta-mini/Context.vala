namespace Meta
{
	/**
	 * Mini stand-in so shared {@link GnomeShellRpc.GiStub.Runtime} can register.
	 */
	public class Context : GLib.Object
	{
		public static void register()
		{
			OLLMrpc.Bin.register("Meta-Context", typeof(Context));
		}

		public Backend get_backend()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Context.get_backend", this);
			var backend = new Backend();
			backend.set_data(
				"gsr-lease-id",
				response.args.get(0).get_uint64().to_string()
			);
			return backend;
		}
	}
}
