		/**
		 * GJS: {@code new Clutter.Interval({ value_type: pspec.value_type })}.
		 * Mint via Gsr-Clutter-Interval.create. Client Vala is set_*_value;
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
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Clutter-Interval.create",
				null,
				OLLMrpc.args("s", this.priv_value_type.name()));
			this.rpc_lid = response.args.get(0).get_uint64();
			Gsr.Client.Rpc.register_handle(this);
		}

		public Interval()
		{
			Object();
		}

		/**
		 * Stock {@code clutter_interval_new_with_values}. Vala adds the
		 * {@code new_} prefix for the named {@code with_values} constructor.
		 * GJS dlsyms this when the class is first touched.
		 */
		public Interval.with_values(
			GLib.Type gtype,
			GLib.Value* initial,
			GLib.Value* final
		) {
			Object(value_type: gtype);
			if (initial != null) {
				this.set_initial_value(*initial);
			}
			if (final != null) {
				this.set_final_value(*final);
			}
		}

		public void set_initial_value(GLib.Value value)
		{
			this.mirror_value(true, value);
			if (this.send_actor_box(true, value)) {
				return;
			}
			Gsr.Client.Rpc.call_value(
				"Clutter-Interval.set_initial", this,
				OLLMrpc.args("V", value));
		}

		public void set_final_value(GLib.Value value)
		{
			this.mirror_value(false, value);
			if (this.send_actor_box(false, value)) {
				return;
			}
			Gsr.Client.Rpc.call_value(
				"Clutter-Interval.set_final", this,
				OLLMrpc.args("V", value));
		}

		/**
		 * Bin GValue rejects {@code ClutterActorBox}. Pack the struct
		 * the same way {@code Actor.allocate} packs a box.
		 */
		private bool send_actor_box(bool is_initial, GLib.Value value)
		{
			if (value.type().name() != "ClutterActorBox") {
				return false;
			}
			unowned Clutter.ActorBox* boxp =
				(Clutter.ActorBox*) value.get_boxed();
			if (boxp == null) {
				return false;
			}
			uint8[] data = new uint8[sizeof(Clutter.ActorBox)];
			*((Clutter.ActorBox*) data) = *boxp;
			Gsr.Client.Rpc.call_value(
				is_initial
					? "Gsr-Clutter-Interval.set_initial_box"
					: "Gsr-Clutter-Interval.set_final_box",
				null,
				OLLMrpc.args("tay", this.rpc_lid, new GLib.Bytes(data)));
			return true;
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

		/**
		 * Keep the GValue {@code peek_*} returns. {@code Transition.set_to}
		 * / {@code set_from} write the server interval and do not pass
		 * through {@link set_initial_value}, so without this the mirror
		 * stays empty and GJS reads the null peek as 0.
		 */
		public void mirror_value(bool is_initial, GLib.Value value)
		{
			if (is_initial) {
				this.priv_initial = GLib.Value(value.type());
				value.copy(ref this.priv_initial);
				this.priv_has_initial = true;
				return;
			}
			this.priv_final = GLib.Value(value.type());
			value.copy(ref this.priv_final);
			this.priv_has_final = true;
		}
