		/**
		 * Stock construct-only props — GJS constructs with
		 * {@code {meta_display, monitor}}.
		 */
		public Display meta_display { get; construct; }
		public int monitor { get; construct; }

		/**
		 * Null-arg {@code Meta-BackgroundActor.new} is -32602.
		 * Lease the Helper. Bind the content peer it returns.
		 * A later call keeps the lease.
		 */
		public override void rpc_construct()
		{
			if (this.rpc_lid != 0) {
				return;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-BackgroundActor.create",
				null,
				OLLMrpc.args("oi", this.meta_display, this.monitor)
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
