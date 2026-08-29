		/**
		 * Quit the client loop only — never tear down mutter-rpc.
		 *
		 * @param error unused (stock API); logged for diagnose
		 */
		public void terminate_with_error(GLib.Error error)
		{
			GLib.warning(
				"Meta.Context.terminate_with_error: %s", error.message);
			this.terminate();
		}

		/**
		 * Quit the client loop only — never tear down mutter-rpc.
		 */
		public void terminate()
		{
			var loop = this.get_data<GLib.MainLoop>("gsr-client-main-loop");
			if (loop != null && loop.is_running()) {
				loop.quit();
			}
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
		 * Stock returns gboolean / throws; GJS ignores the return.
		 *
		 * @return always true after the local loop quits
		 */
		public bool run_main_loop() throws GLib.Error
		{
			var loop = new GLib.MainLoop(null, false);
			this.set_data("gsr-client-main-loop", loop);
			loop.run();
			return true;
		}
