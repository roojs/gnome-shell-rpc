namespace Meta
{
	/**
	 * Hand Meta mini stub for plan 0.5.6 B2 smoke.
	 *
	 * Bodies match ''IdleMonitor.override.vala'' (callback id + helper RPC).
	 * Delegate matches mutter Vala (no GIR user_data).
	 */
	public delegate void IdleMonitorWatchFunc(IdleMonitor monitor, uint32 watch_id);

	public class IdleMonitor : GLib.Object
	{
		public uint32 add_idle_watch(
			uint64 interval_msec,
			IdleMonitorWatchFunc callback
		) {
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				callback(
					(IdleMonitor) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
						(int) call.args.get(0).get_uint64()),
					(uint32) call.args.get(1).get_uint());
				return null;
			});
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-IdleMonitor.add_idle_watch",
				this,
				OLLMrpc.args("tt", interval_msec, callback_id));
			return (uint32) response.args.get(0).get_uint();
		}

		public uint32 add_user_active_watch(IdleMonitorWatchFunc callback)
		{
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				callback(
					(IdleMonitor) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
						(int) call.args.get(0).get_uint64()),
					(uint32) call.args.get(1).get_uint());
				return null;
			});
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-IdleMonitor.add_user_active_watch",
				this,
				OLLMrpc.args("t", callback_id));
			return (uint32) response.args.get(0).get_uint();
		}

		public void remove_watch(uint32 id)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-IdleMonitor.remove_watch",
				this,
				OLLMrpc.args("u", (uint) id));
		}
	}
}

