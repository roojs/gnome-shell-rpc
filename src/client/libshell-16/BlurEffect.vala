/**
 * Owned {@code Shell.BlurEffect} — stock {@code shell-blur-effect} surface.
 *
 * Paint runs on the compositor via {@code Gsr-Shell-BlurEffect.create} (lease).
 * Radius, brightness, and mode sync with {@code Gsr-Shell-BlurEffect.sync_radius},
 * {@code sync_brightness}, and {@code sync_mode}.
 */
namespace Shell
{
	public class BlurEffect : Clutter.Effect, OLLMrpc.Live.Interface
	{
		[CCode (gir = false)]
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
					Gsr.Client.Rpc.call_value("Clutter-ActorMeta.set_enabled", this,
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
					Gsr.Client.Rpc.call_value("Gsr-Shell-BlurEffect.sync_radius", this,
						OLLMrpc.args("i", this.priv_radius));
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
					Gsr.Client.Rpc.call_value("Gsr-Shell-BlurEffect.sync_brightness", this,
						OLLMrpc.args("f", this.priv_brightness));
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
					Gsr.Client.Rpc.call_value("Gsr-Shell-BlurEffect.sync_mode", this,
						OLLMrpc.args("i", (int) this.priv_mode));
				}
			}
		}

		construct {
			if (this.rpc_lid != 0) {
				this.mint_done = true;
				return;
			}
			var response = Gsr.Client.Rpc.call_value("Gsr-Shell-BlurEffect.create");
			this.rpc_lid = response.args.get(0).get_uint64();
			Gsr.Client.Rpc.register_handle(this);
			if (this.priv_name != null && this.priv_name.length > 0) {
				Gsr.Client.Rpc.call_value("Clutter-ActorMeta.set_name", this,
					OLLMrpc.args("s", this.priv_name));
			}
			Gsr.Client.Rpc.call_value("Clutter-ActorMeta.set_enabled", this,
				OLLMrpc.args("b", this.priv_enabled));
			Gsr.Client.Rpc.call_value("Gsr-Shell-BlurEffect.sync_radius", this,
				OLLMrpc.args("i", this.priv_radius));
			Gsr.Client.Rpc.call_value("Gsr-Shell-BlurEffect.sync_brightness", this,
				OLLMrpc.args("f", this.priv_brightness));
			Gsr.Client.Rpc.call_value("Gsr-Shell-BlurEffect.sync_mode", this,
				OLLMrpc.args("i", (int) this.priv_mode));
			this.mint_done = true;
		}
	}
}
