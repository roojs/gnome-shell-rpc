		/**
		 * Stock construct-only props — GJS constructs with
		 * {@code {meta_display, monitor}}.
		 */
		public Display meta_display { get; construct; }
		public int monitor { get; construct; }

		/**
		 * Actor parent-walk defers here (null-arg {@code .new} is -32602).
		 * Wire import already has {@code rpc_lid} — skip remint.
		 */
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var response = GnomeShellRpc.call_value(
				"Helper-BackgroundActor.create",
				null,
				OLLMrpc.args("ti", this.meta_display.rpc_lid, this.monitor)
			);
			this.rpc_lid = response.args.get(0).get_uint64();
			/* Stock meta_background_actor_new attaches MetaBackgroundContent.
			 * Bind the client facade to that lease so content.background RPCs. */
			var content = new BackgroundContent();
			if (response.args.size > 1) {
				content.rpc_lid = response.args.get(1).get_uint64();
			}
			this.content = content;
		}
