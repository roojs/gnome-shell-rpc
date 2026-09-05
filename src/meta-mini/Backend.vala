namespace Meta
{
	/**
	 * Client stub for {@code Meta.Backend} (plan 0.5.6 B2).
	 *
	 * {@link get_core_idle_monitor} is the stock shell path
	 * ({@code global.backend.get_core_idle_monitor()}).
	 */
	public class Backend : GLib.Object, OLLMrpc.Live.Handle
	{
		public uint64 rpc_lid { get; set construct; default = 0; }

		public static void register()
		{
			OLLMrpc.Bin.register("Meta-Backend", typeof(Backend));
		}

		public IdleMonitor get_core_idle_monitor()
		{
			var response = GnomeShellRpc.call_value(
				"Meta-Backend.get_core_idle_monitor", this);
			var monitor = new IdleMonitor();
			monitor.rpc_lid = response.args.get(0).get_uint64();
			return monitor;
		}
	}
}
