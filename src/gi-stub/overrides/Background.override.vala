		/**
		 * Stock construct-only prop — typelib lists it; GJS uses
		 * {@code new Meta.Background({meta_display})} / {@code super._init}.
		 */
		public Display meta_display { get; construct; }

		construct {
			var response = GnomeShellRpc.call_value(
				"Helper-Background.create",
				null,
				OLLMrpc.args("t", this.meta_display.rpc_lid)
			);
			this.rpc_lid = response.args.get(0).get_uint64();
		}

		public void set_file(GLib.File file, GDesktop.BackgroundStyle style)
		{
			GnomeShellRpc.call_value(
				"Helper-Background.set_file",
				this,
				OLLMrpc.args(
					"si",
					file != null ? file.get_uri() : "",
					(int) style
				)
			);
		}
