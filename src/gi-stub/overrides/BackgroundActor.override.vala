		/**
		 * Stock construct-only props — GJS constructs with
		 * {@code {meta_display, monitor}}.
		 */
		public Display meta_display { get; construct; }
		public int monitor { get; construct; }

		construct {
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-BackgroundActor.create",
				null,
				OLLMrpc.args("ti", this.meta_display.rpc_lid, this.monitor)
			);
			this.rpc_lid = response.args.get(0).get_uint64();
		}
