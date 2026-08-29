		/**
		 * Stock construct-only prop — typelib lists it; GJS uses
		 * {@code new Meta.Background({meta_display})} / {@code super._init}.
		 */
		public Display meta_display { get; construct; }

		construct {
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Background.new",
				null,
				OLLMrpc.args("o", this.meta_display)
			);
			var stub = (Background) response.result.get(0);
			this.set_data(
				"gsr-lease-id",
				stub.get_data<string>("gsr-lease-id")
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
