		/**
		 * Lease handle in {@code args[0]} — Ui.Backend packs uint64, not
		 * {@code result} (live GObject rows arrive with handle 0).
		 *
		 * Returns {@link Clutter.Stage} (in Clutter typelib) — not
		 * {@code Meta.Stage}, which our hand Meta-16.gir omits.
		 */
		public Clutter.Actor get_stage()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Backend.get_stage", this);
			var stage = new Clutter.Stage();
			if (response.args.size > 0) {
				stage.set_data_full(
					"gsr-lease-id",
					(void*) response.args.get(0).get_uint64(),
					null
				);
			}
			return stage;
		}

		/**
		 * Lease handle in {@code args[0]} — same packing as {@link get_stage}.
		 */
		public IdleMonitor get_core_idle_monitor()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Backend.get_core_idle_monitor", this);
			var monitor = new IdleMonitor();
			if (response.args.size > 0) {
				monitor.set_data_full(
					"gsr-lease-id",
					(void*) response.args.get(0).get_uint64(),
					null
				);
			}
			return monitor;
		}
