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
