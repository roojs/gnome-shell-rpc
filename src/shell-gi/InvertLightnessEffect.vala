/**
 * Owned {@code Shell.InvertLightnessEffect} — stock
 * {@code shell-invert-lightness-effect}.
 *
 * Paint runs on the compositor via {@code Helper-InvertLightnessEffect.create}.
 */
namespace Shell
{
	public class InvertLightnessEffect : Clutter.OffscreenEffect, OLLMrpc.Live.Handle
	{
		public uint64 rpc_lid { get; set construct; default = 0; }

		private string priv_name;
		private bool priv_enabled = true;
		private bool mint_done = false;

		public string name {
			get {
				return this.priv_name;
			}
			set construct {
				this.priv_name = value;
			}
		}

		public bool enabled {
			get {
				return this.priv_enabled;
			}
			set construct {
				this.priv_enabled = value;
				if (this.mint_done) {
					GnomeShellRpc.call_value("Clutter-ActorMeta.set_enabled", this,
						OLLMrpc.args("b", this.priv_enabled));
				}
			}
		}

		construct {
			if (this.rpc_lid != 0) {
				this.mint_done = true;
				return;
			}
			var response = GnomeShellRpc.call_value(
				"Helper-InvertLightnessEffect.create", null);
			this.rpc_lid = response.args.get(0).get_uint64();
			if (this.priv_name != null && this.priv_name.length > 0) {
				GnomeShellRpc.call_value("Clutter-ActorMeta.set_name", this,
					OLLMrpc.args("s", this.priv_name));
			}
			GnomeShellRpc.call_value("Clutter-ActorMeta.set_enabled", this,
				OLLMrpc.args("b", this.priv_enabled));
			this.mint_done = true;
		}
	}
}
