		/**
		 * Stock construct-only prop — typelib lists it; GJS uses
		 * {@code new Meta.Background({meta_display})} / {@code super._init}.
		 */
		public Display meta_display { get; construct; }

		construct {
			var lease = (uint64) this.meta_display.get_data<void*>("gsr-lease-id");
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Background.create",
				null,
				OLLMrpc.args("t", lease)
			);
			this.set_data_full(
				"gsr-lease-id",
				(void*) response.args.get(0).get_uint64(),
				null
			);
		}

		public void set_file(GLib.File file, GDesktop.BackgroundStyle style)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Background.set_file",
				this,
				OLLMrpc.args(
					"si",
					file != null ? file.get_uri() : "",
					(int) style
				)
			);
		}
