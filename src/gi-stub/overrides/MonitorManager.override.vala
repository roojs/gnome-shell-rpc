		/**
		 * Stock {@code night-light-supported} (GIR property, no getter method).
		 * Compositor value via stock {@code GObject.get_property} on the lease.
		 */
		public bool night_light_supported {
			get {
				var response = GnomeShellRpc.call_value(
					"Meta-MonitorManager.get_property", this,
					OLLMrpc.args("s", "night-light-supported"));
				return response.retval.get_boolean();
			}
		}
