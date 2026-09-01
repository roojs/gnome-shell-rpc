namespace Meta
{
	/**
	 * Client stub for {@code Meta.Backend} (plan 0.5.6 B2).
	 *
	 * {@link get_core_idle_monitor} is the stock shell path
	 * ({@code global.backend.get_core_idle_monitor()}).
	 */
	public class Backend : GLib.Object
	{
		public static void register()
		{
			OLLMrpc.Bin.register("Meta-Backend", typeof(Backend));
		}

		public IdleMonitor get_core_idle_monitor()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Backend.get_core_idle_monitor", this);
			var monitor = new IdleMonitor();
			monitor.set_data_full(
				"rpc-lid",
				(void*) response.args.get(0).get_uint64(),
				null
			);
			return monitor;
		}
	}
}
