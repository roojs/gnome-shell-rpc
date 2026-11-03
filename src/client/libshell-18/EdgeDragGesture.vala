/**
 * {@code Shell.EdgeDragGesture} — stock {@code shell-edge-drag-gesture.c}.
 *
 * Shell 50 constructs this from {@code ui/windowManager.js} with
 * {@code name} and {@code side}, then sets {@code enabled}.
 * {@code Clutter.ActorMeta} exposes those as methods, not properties,
 * so the construct hash cannot see them. Same pattern as
 * {@link BlurEffect}.
 */
namespace Shell
{
	public class EdgeDragGesture : Clutter.Gesture
	{
		private string priv_name;
		private bool priv_enabled = true;
		private St.Side priv_side;

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
			}
		}

		public St.Side side {
			get {
				return this.priv_side;
			}
			set construct {
				this.priv_side = value;
			}
		}

		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var response = Gsr.Client.Rpc.call_value("Gsr-Shell-EdgeDragGesture.create");
			this.rpc_lid = response.args.get(0).get_uint64();
			Gsr.Client.Rpc.register_handle(this);
			if (this.priv_name != null && this.priv_name.length > 0) {
				Gsr.Client.Rpc.call_value("Clutter-ActorMeta.set_name", this,
					OLLMrpc.args("s", this.priv_name));
			}
			Gsr.Client.Rpc.call_value("Clutter-ActorMeta.set_enabled", this,
				OLLMrpc.args("b", this.priv_enabled));
		}
	}
}
