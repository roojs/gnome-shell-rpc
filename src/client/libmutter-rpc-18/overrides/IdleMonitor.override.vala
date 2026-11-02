		public uint32 add_idle_watch(uint64 interval_msec, IdleMonitorWatchFunc callback)
		{
			var callback_id = Gsr.Client.Rpc.callback_bind((call) => {
				callback(
					(IdleMonitor) Gsr.Client.Rpc.client.proxies.get(
						(int) call.args.get(0).get_uint64()),
					(uint32) call.args.get(1).get_uint());
				return null;
			});
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-IdleMonitor.add_idle_watch",
				this,
				OLLMrpc.args("tt", interval_msec, callback_id));
			return (uint32) response.retval.get_uint();
		}

		/**
		 * Stock {@code meta_idle_monitor_add_idle_watch_full}.
		 * Same callback relay as {@link add_idle_watch}, plus the
		 * flags the break timer passes.
		 *
		 * @param interval_msec idle interval
		 * @param callback invoked when the interval elapses
		 * @param flags {@link IdleMonitorWatchFlags}
		 * @return watch id from the compositor
		 */
		[CCode (cname = "gsr_meta_idle_monitor_add_idle_watch_full")]
		public uint32 add_idle_watch_full(
			uint64 interval_msec,
			IdleMonitorWatchFunc callback,
			IdleMonitorWatchFlags flags
		) {
			var callback_id = Gsr.Client.Rpc.callback_bind((call) => {
				callback(
					(IdleMonitor) Gsr.Client.Rpc.client.proxies.get(
						(int) call.args.get(0).get_uint64()),
					(uint32) call.args.get(1).get_uint());
				return null;
			});
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-IdleMonitor.add_idle_watch_full",
				this,
				OLLMrpc.args("ttu", interval_msec, callback_id, (uint) flags));
			return (uint32) response.retval.get_uint();
		}

		public uint32 add_user_active_watch(IdleMonitorWatchFunc callback)
		{
			var callback_id = Gsr.Client.Rpc.callback_bind((call) => {
				callback(
					(IdleMonitor) Gsr.Client.Rpc.client.proxies.get(
						(int) call.args.get(0).get_uint64()),
					(uint32) call.args.get(1).get_uint());
				return null;
			});
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-IdleMonitor.add_user_active_watch",
				this,
				OLLMrpc.args("t", callback_id));
			return (uint32) response.retval.get_uint();
		}
