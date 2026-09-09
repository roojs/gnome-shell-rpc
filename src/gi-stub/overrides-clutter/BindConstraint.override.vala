		/**
		 * Client-owned for {@code layout.js} JSObject
		 * {@code new Clutter.BindConstraint({ source, coordinate })}.
		 * Lease: {@code Clutter-BindConstraint.new} → real mutter BindConstraint.
		 * Construct props apply before mint — push after lease.
		 */
		private Actor? priv_source;
		private BindCoordinate priv_coordinate = BindCoordinate.all;
		private float priv_offset = 0;

		public Actor? source {
			get {
				return this.priv_source;
			}
			set construct {
				this.priv_source = value;
				this.sync_source();
			}
		}

		public BindCoordinate coordinate {
			get {
				return this.priv_coordinate;
			}
			set construct {
				this.priv_coordinate = value;
				this.sync_coordinate();
			}
		}

		public float offset {
			get {
				return this.priv_offset;
			}
			set construct {
				this.priv_offset = value;
				this.sync_offset();
			}
		}

		protected override void mint_server_lease()
		{
			var response = GnomeShellRpc.call_value(
				"Clutter-BindConstraint.new", null);
			this.rpc_lid = response.args.get(0).get_uint64();
			this.sync_source();
			this.sync_coordinate();
			this.sync_offset();
		}

		private void sync_source()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			GnomeShellRpc.call_value(
				"Clutter-BindConstraint.set_source", this,
				OLLMrpc.args("o", this.priv_source));
		}

		private void sync_coordinate()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			GnomeShellRpc.call_value(
				"Clutter-BindConstraint.set_coordinate", this,
				OLLMrpc.args("i", (int) this.priv_coordinate));
		}

		private void sync_offset()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			GnomeShellRpc.call_value(
				"Clutter-BindConstraint.set_offset", this,
				OLLMrpc.args("f", (double) this.priv_offset));
		}
