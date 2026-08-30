		/**
		 * Stock construct-only props — GJS constructs with
		 * {@code {meta_display, monitor}}.
		 */
		public Display meta_display { get; construct; }
		public int monitor { get; construct; }

		construct {
			var lease = (uint64) this.meta_display.get_data<void*>("gsr-lease-id");
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-BackgroundActor.create",
				null,
				OLLMrpc.args("ti", lease, this.monitor)
			);
			this.set_data_full(
				"gsr-lease-id",
				(void*) response.args.get(0).get_uint64(),
				null
			);
		}
