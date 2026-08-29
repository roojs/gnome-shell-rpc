		public void terminate_with_error(GLib.Error error)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Context.terminate_with_error",
				this,
				OLLMrpc.args(
					"sis",
					error.domain.to_string(),
					error.code,
					error.message
				)
			);
		}

		/**
		 * Lease handle in {@code args[0]} — Ui.Context packs uint64, not
		 * {@code result} (live GObject rows arrive with handle 0).
		 */
		public Backend get_backend()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Context.get_backend", this);
			var backend = new Backend();
			if (response.args.size > 0) {
				backend.set_data(
					"gsr-lease-id",
					response.args.get(0).get_uint64().to_string()
				);
			}
			return backend;
		}

		/**
		 * Client GLib loop — compositor main loop stays in mutter-rpc.
		 */
		public void run_main_loop()
		{
			var loop = new GLib.MainLoop(null, false);
			loop.run();
		}
