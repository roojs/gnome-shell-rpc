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
		 * Client GLib loop — compositor main loop stays in mutter-rpc.
		 */
		public void run_main_loop()
		{
			var loop = new GLib.MainLoop(null, false);
			loop.run();
		}
