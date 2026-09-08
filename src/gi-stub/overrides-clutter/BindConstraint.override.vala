		/**
		 * Client-owned for {@code layout.js} JSObject
		 * {@code new Clutter.BindConstraint({ source, coordinate })}.
		 * Lease: {@code Clutter-BindConstraint.new} → real mutter BindConstraint.
		 */
		public Actor? source { get; set construct; }
		public BindCoordinate coordinate { get; set construct; default = BindCoordinate.all;}
		public float offset { get; set construct; default = 0; }

		protected override void mint_server_lease()
		{
			var response = GnomeShellRpc.call_value(
				"Clutter-BindConstraint.new", null);
			this.rpc_lid = response.args.get(0).get_uint64();
		}
