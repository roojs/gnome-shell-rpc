		/**
		 * Stock construct-only prop — typelib lists it; GJS uses
		 * {@code new Meta.Background({meta_display})} / {@code super._init}.
		 */
		public Display meta_display { get; construct; }

		construct {
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Background.create",
				null,
				OLLMrpc.args("o", this.meta_display)
			);
			this.rpc_lid = response.args.get(0).get_uint64();
		}

		public void set_file(GLib.File file, GDesktop.BackgroundStyle style)
		{
			Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Background.set_file",
				this,
				OLLMrpc.args(
					"si",
					file != null ? file.get_uri() : "",
					(int) style
				)
			);
		}
