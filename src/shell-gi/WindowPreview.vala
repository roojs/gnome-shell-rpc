/**
 * Owned {@code Shell.WindowPreview} — stock shell-window-preview (0.7.7 T-038).
 *
 * GJS subclasses set {@link window_container}; preferred size follows that child.
 */
namespace Shell
{
	public class WindowPreview : St.Widget
	{
		public Clutter.Actor? window_container { get; set; default = null; }

		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var t = this.get_type();
			if (t != typeof(WindowPreview) && !t.name().has_prefix("Gjs_")) {
				return;
			}
			var response = GnomeShellRpc.call_value("St-Widget.new", null);
			var stub = response.retval.get_object() as OLLMrpc.Live.Handle;
			this.rpc_lid = stub.rpc_lid;
		}

		public override void get_preferred_width(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			if (this.window_container == null) {
				min_width_p = 0;
				natural_width_p = 0;
				return;
			}
			this.window_container.get_preferred_width(for_height, out min_width_p, out natural_width_p);
		}

		public override void get_preferred_height(
			float for_width,
			out float min_height_p,
			out float natural_height_p
		) {
			if (this.window_container == null) {
				min_height_p = 0;
				natural_height_p = 0;
				return;
			}
			this.window_container.get_preferred_height(for_width, out min_height_p, out natural_height_p);
		}
	}
}
