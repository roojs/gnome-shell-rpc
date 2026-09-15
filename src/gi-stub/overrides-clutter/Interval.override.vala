		/**
		 * GIR {@code value-type} is construct-only; generator skips it because
		 * {@code GType} is not wireable and there is no setter. GJS
		 * {@code new Clutter.Interval({value_type})} (environment.js ease)
		 * needs the prop + a helper mint with that type.
		 *
		 * Cache the construct type locally — same process fundamentals
		 * ({@code G_TYPE_DOUBLE}, …) match the helper object.
		 */
		private GLib.Type priv_value_type;

		public GLib.Type value_type {
			get {
				return this.priv_value_type;
			}
			construct set {
				this.priv_value_type = value;
			}
		}

		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var response = GnomeShellRpc.call_value(
				"Helper-Clutter.new_interval_for_type",
				null,
				OLLMrpc.args("t", (uint64) this.priv_value_type));
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Handle).rpc_lid;
		}
