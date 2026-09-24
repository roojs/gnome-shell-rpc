/**
 * Owned {@code Shell.BlurEffect} — stock {@code shell-blur-effect} surface.
 *
 * Paint runs on the compositor via {@code Helper-BlurEffect.create} (lease).
 * Radius / brightness / mode sync with stock {@code Shell-BlurEffect.set_property}.
 */
namespace Shell
{
	public class BlurEffect : Clutter.Effect, OLLMrpc.Live.Interface
	{
		public uint64 rpc_lid { get; set construct; default = 0; }

		private string priv_name;
		private bool priv_enabled = true;
		private int priv_radius = 0;
		private float priv_brightness = 1f;
		private BlurMode priv_mode = BlurMode.ACTOR;
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

		public int radius {
			get {
				return this.priv_radius;
			}
			set construct {
				this.priv_radius = value;
				if (this.mint_done) {
					GnomeShellRpc.call_value("Shell-BlurEffect.set_property", this,
						OLLMrpc.args("si", "radius", this.priv_radius));
				}
			}
		}

		public float brightness {
			get {
				return this.priv_brightness;
			}
			set construct {
				this.priv_brightness = value;
				if (this.mint_done) {
					GnomeShellRpc.call_value("Shell-BlurEffect.set_property", this,
						OLLMrpc.args("sf", "brightness", this.priv_brightness));
				}
			}
		}

		public BlurMode mode {
			get {
				return this.priv_mode;
			}
			set construct {
				this.priv_mode = value;
				if (this.mint_done) {
					GnomeShellRpc.call_value("Shell-BlurEffect.set_property", this,
						OLLMrpc.args("si", "mode", (int) this.priv_mode));
				}
			}
		}

		construct {
			if (this.rpc_lid != 0) {
				this.mint_done = true;
				return;
			}
			var response = GnomeShellRpc.call_value("Helper-BlurEffect.create");
			this.rpc_lid = response.args.get(0).get_uint64();
			if (this.priv_name != null && this.priv_name.length > 0) {
				GnomeShellRpc.call_value("Clutter-ActorMeta.set_name", this,
					OLLMrpc.args("s", this.priv_name));
			}
			GnomeShellRpc.call_value("Clutter-ActorMeta.set_enabled", this,
				OLLMrpc.args("b", this.priv_enabled));
			GnomeShellRpc.call_value("Shell-BlurEffect.set_property", this,
				OLLMrpc.args("si", "radius", this.priv_radius));
			GnomeShellRpc.call_value("Shell-BlurEffect.set_property", this,
				OLLMrpc.args("sf", "brightness", this.priv_brightness));
			GnomeShellRpc.call_value("Shell-BlurEffect.set_property", this,
				OLLMrpc.args("si", "mode", (int) this.priv_mode));
			this.mint_done = true;
		}
	}
}
