		/**
		 * Stock construct-only props — GJS constructs with
		 * {@code {meta_display, monitor}}.
		 */
		public Display meta_display { get; construct; }
		public int monitor { get; construct; }

		construct {
			var response = GnomeShellRpc.call_value(
				"Helper-BackgroundActor.create",
				null,
				OLLMrpc.args("ti", this.meta_display.rpc_lid, this.monitor)
			);
			this.rpc_lid = response.args.get(0).get_uint64();
			/* Stock meta_background_actor_new attaches MetaBackgroundContent. */
			this.content = new BackgroundContent();
		}
