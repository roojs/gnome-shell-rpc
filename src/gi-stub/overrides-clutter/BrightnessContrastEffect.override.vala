		/**
		 * ActorMeta name/enabled — parent is size-locked C GType.
		 * Setters must not RPC: wire decode of {@code .new} uses
		 * {@code Object.new(..., "rpc-lid")} and would nest mid-reply.
		 * Push after local lease below.
		 */
		public string name { get; set construct; }
		public bool enabled { get; set construct; default = true; }

		/**
		 * Generated lease-on-construct denied ({@code BrightnessContrastEffect.new}).
		 * Wire decode ({@code rpc_lid != 0}): return without sync.
		 */
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var response = GnomeShellRpc.call_value(
				"Clutter-BrightnessContrastEffect.new", null);
			var stub = response.retval.get_object() as OLLMrpc.Live.Handle;
			this.rpc_lid = stub.rpc_lid;
			if (this.name != null && this.name.length > 0) {
				GnomeShellRpc.call_value("Clutter-ActorMeta.set_name", this,
					OLLMrpc.args("s", this.name));
			}
			GnomeShellRpc.call_value("Clutter-ActorMeta.set_enabled", this,
				OLLMrpc.args("b", this.enabled));
		}
