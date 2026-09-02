		public BindConstraint (Actor source, BindCoordinate coordinate, float offset)
		{
			Object (source: source, coordinate: coordinate, offset: offset);
		}

		protected override void constructed ()
		{
			base.constructed ();
			if (this.rpc_lid != 0) {
				return;
			}
			if (this.get_type () != typeof (BindConstraint)) {
				return;
			}
			/* Source is a local GJS/St actor until leased; skip RPC with lid 0. */
			if (this.source == null || this.source.rpc_lid == 0) {
				return;
			}
			var response = GnomeShellRpc.GiStub.Runtime.call_values (
				"Clutter-BindConstraint.new", null,
				OLLMrpc.args ("oif", this.source,
					(int) this.coordinate, (double) this.offset));
			var _stub = (BindConstraint) response.retval.get_object ();
			this.rpc_lid = _stub.rpc_lid;
		}
