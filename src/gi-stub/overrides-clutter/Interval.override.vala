		/**
		 * GJS: {@code new Clutter.Interval({ value_type: pspec.value_type })}.
		 * GIR {@code value-type} is construct-only — own it locally; mint via
		 * Helper-Interval.create with the GLib type name (no type switch).
		 * See docs/bugs/done/2026-09-16-interval-value-type-mint.md (1.0 D1.8).
		 */
		private GLib.Type priv_value_type = GLib.Type.INVALID;

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
				"Helper-Interval.create", null,
				OLLMrpc.args("s", this.priv_value_type.name()));
			this.rpc_lid = response.args.get(0).get_uint64();
			GnomeShellRpc.GiStub.Runtime.register_handle(this);
		}

		public Interval()
		{
			Object();
		}
