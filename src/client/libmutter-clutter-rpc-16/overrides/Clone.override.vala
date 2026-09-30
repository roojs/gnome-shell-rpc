		/**
		 * GIR ctor is {@code new(source)} ({@code source} nullable). Generated
		 * lease construct called {@code .new} with no args (-32602). GJS uses
		 * empty {@code new Clutter.Clone()} then {@code set_source}, or
		 * {@code { source }}. Actor parent construct skips this type.
		 */
		private Actor? priv_source;
		private bool mint_done = false;

		public Actor? source {
			get {
				return this.priv_source;
			}
			set construct {
				this.priv_source = value;
				if (this.mint_done) {
					GnomeShellRpc.call_value(
						"Clutter-Clone.set_source", this,
						OLLMrpc.args("o", this.priv_source));
				}
			}
		}

		public Clone(Actor? source = null)
		{
			Object(source: source);
		}

		construct {
			if (this.rpc_lid != 0) {
				this.mint_done = true;
				return;
			}
			var response = GnomeShellRpc.call_value(
				"Clutter-Clone.new",
				null,
				OLLMrpc.args("o", this.priv_source));
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
			GnomeShellRpc.GiStub.Runtime.register_handle(this);
			this.mint_done = true;
		}
