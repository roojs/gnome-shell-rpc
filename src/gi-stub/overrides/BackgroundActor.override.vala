		/**
		 * Stock construct-only props — GJS constructs with
		 * {@code {meta_display, monitor}}.
		 */
		public Display meta_display { get; construct; }
		public int monitor { get; construct; }

		construct {
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-BackgroundActor.new",
				null,
				OLLMrpc.args("oi", this.meta_display, this.monitor)
			);
			var stub = (BackgroundActor) response.result.get(0);
			this.set_data(
				"gsr-lease-id",
				stub.get_data<string>("gsr-lease-id")
			);
		}
