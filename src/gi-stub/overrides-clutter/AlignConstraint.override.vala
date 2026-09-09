		/**
		 * Stock AlignConstraint — real mutter object via
		 * {@code Clutter-AlignConstraint.new} (not Helper.Constraint base).
		 */
		protected override void mint_server_lease()
		{
			var response = GnomeShellRpc.call_value(
				"Clutter-AlignConstraint.new", null);
			this.rpc_lid = response.args.get(0).get_uint64();
		}

		/**
		 * GIR pivot-point getter is OUT Graphene.Point — generator skips the
		 * property; get/set_pivot_point denied (C symbol clash with property
		 * accessors). Inline RPC for ScreenshotUI construct literals.
		 */
		public Graphene.Point pivot_point {
			get {
				var response = GnomeShellRpc.call_value(
					"Clutter-AlignConstraint.get_pivot_point", this);
				var blob = (GLib.Bytes) response.args.get(0).get_boxed();
				return *((Graphene.Point*) blob.get_data());
			}
			set {
				uint8[] data = new uint8[sizeof(Graphene.Point)];
				*((Graphene.Point*) data) = value;
				var bytes = new GLib.Bytes(data);
				GnomeShellRpc.call_value(
					"Clutter-AlignConstraint.set_pivot_point", this,
					OLLMrpc.args("ay", bytes));
			}
		}
