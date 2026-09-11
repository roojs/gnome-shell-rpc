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
		 * {@code Meta-Context.terminate} on the server, then quit the
		 * client loop. Live compositor acks and keeps running; mock exits.
		 */
		public void terminate()
		{
			try {
				GnomeShellRpc.call_value(
					"Meta-Context.terminate", this);
			} catch (GLib.Error e) {
				GLib.warning(
					"Meta.Context.terminate: %s", e.message);
			}
			var loop = this.get_data<GLib.MainLoop>("gsr-client-main-loop");
			if (loop != null && loop.is_running()) {
				loop.quit();
			}
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
