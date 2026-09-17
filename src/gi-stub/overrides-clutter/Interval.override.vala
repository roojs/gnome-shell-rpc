		/**
		 * GJS: {@code new Clutter.Interval({ value_type: pspec.value_type })}.
		 * Mint via Helper-Interval.create. Client Vala is set_*_value;
		 * Gi typelib name is set_initial / set_final (GIR shadows). Wire
		 * that + capital-V. peek/get keep a local mirror (GValue* ABI).
		 */
		private GLib.Type priv_value_type = GLib.Type.INVALID;
		private GLib.Value priv_initial;
		private GLib.Value priv_final;
		private bool priv_has_initial;
		private bool priv_has_final;

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

		public void set_initial_value(GLib.Value value)
		{
			this.store_and_relay(true, value);
		}

		public void set_final_value(GLib.Value value)
		{
			this.store_and_relay(false, value);
		}

		public void get_initial_value(out GLib.Value value)
		{
			value = GLib.Value(this.priv_has_initial
				? this.priv_initial.type() : this.priv_value_type);
			if (this.priv_has_initial) {
				this.priv_initial.copy(ref value);
			}
		}

		public void get_final_value(out GLib.Value value)
		{
			value = GLib.Value(this.priv_has_final
				? this.priv_final.type() : this.priv_value_type);
			if (this.priv_has_final) {
				this.priv_final.copy(ref value);
			}
		}

		[CCode (cname = "clutter_interval_peek_initial_value")]
		public GLib.Value* peek_initial_value()
		{
			return this.priv_has_initial ? &this.priv_initial : null;
		}

		[CCode (cname = "clutter_interval_peek_final_value")]
		public GLib.Value* peek_final_value()
		{
			return this.priv_has_final ? &this.priv_final : null;
		}

		void store_and_relay(bool is_initial, GLib.Value value)
		{
			if (is_initial) {
				this.priv_initial = GLib.Value(value.type());
				value.copy(ref this.priv_initial);
				this.priv_has_initial = true;
			} else {
				this.priv_final = GLib.Value(value.type());
				value.copy(ref this.priv_final);
				this.priv_has_final = true;
			}
			var method = is_initial
				? "Clutter-Interval.set_initial"
				: "Clutter-Interval.set_final";
			GnomeShellRpc.call_value(method, this, OLLMrpc.args("V", value));
		}
