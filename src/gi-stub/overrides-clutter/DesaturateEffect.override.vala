		/**
		 * ActorMeta props — parent class is size-locked (no Vala props).
		 *
		 * Order for {@code new DesaturateEffect({ name: 'desaturate' })}:
		 * 1. GObject applies {@code set construct} props ({@code name},
		 *    {@code enabled}, {@code factor}) — store only
		 *    ({@code mint_done} still false; {@code rpc_lid} still 0).
		 * 2. This {@code construct} block mints the server peer with
		 *    {@code .new(factor)}, pushes name/enabled, then sets
		 *    {@code mint_done} (same as BrightnessContrastEffect /
		 *    Constraint store-then-sync).
		 *
		 * Wire decode sets {@code rpc_lid} first → early return (no re-mint).
		 * Construct defaults still run before this block with
		 * {@code mint_done == false}, so {@code factor} must not RPC on
		 * {@code rpc_lid != 0} alone (nests mid-{@code .new} reply parse).
		 */
		public string name { get; set construct; }
		public bool enabled { get; set construct; default = true; }

		/**
		 * GIR ctor is {@code new(factor)}; GJS mostly uses empty /
		 * {@code { name }}. Generated lease construct called {@code .new}
		 * with no args (-32602). Mint with the construct {@code factor}
		 * (default 1.0). Post-construct assigns sync via {@code set_factor}
		 * only after {@code mint_done}.
		 */
		private double priv_factor = 1.0;
		private bool mint_done = false;

		public double factor {
			get {
				return this.priv_factor;
			}
			set construct {
				this.priv_factor = value;
				if (this.mint_done) {
					GnomeShellRpc.call_value(
						"Clutter-DesaturateEffect.set_factor", this,
						OLLMrpc.args("d", this.priv_factor));
				}
			}
		}

		construct {
			if (this.rpc_lid != 0) {
				this.mint_done = true;
				return;
			}
			var response = GnomeShellRpc.call_value(
				"Clutter-DesaturateEffect.new", null,
				OLLMrpc.args("d", this.priv_factor));
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Handle).rpc_lid;
			if (this.name != null && this.name.length > 0) {
				GnomeShellRpc.call_value("Clutter-ActorMeta.set_name", this,
					OLLMrpc.args("s", this.name));
			}
			GnomeShellRpc.call_value("Clutter-ActorMeta.set_enabled", this,
				OLLMrpc.args("b", this.enabled));
			this.mint_done = true;
		}
