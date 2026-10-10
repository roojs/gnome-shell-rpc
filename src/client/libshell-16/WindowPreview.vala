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
			var response = Gsr.Client.Rpc.call_value("St-Widget.new");
			var stub = response.retval.get_object() as OLLMrpc.Live.Interface;
			this.rpc_lid = stub.rpc_lid;
		}

		public override void get_preferred_width_vfunc(
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

		public override void get_preferred_height_vfunc(
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

		/**
		 * Stock {@code shell_window_preview_allocate}: content box, then
		 * {@code clutter_actor_allocate_available_size} on each child.
		 * The default request mode is height-for-width, so the clamp
		 * follows that branch. Without this, {@code St.Widget} allocates
		 * the window container at its preferred size (the full window)
		 * and the card's clone is never scaled into the slot.
		 */
		public override void allocate_vfunc(Clutter.ActorBox box)
		{
			this.relay_allocation(box);
			Clutter.ActorBox content_box;
			this.get_theme_node().get_content_box(box, out content_box);
			float origin_x, origin_y, available_width, available_height;
			content_box.get_origin(out origin_x, out origin_y);
			content_box.get_size(out available_width, out available_height);
			GLib.debug("preview-slot box %.1f,%.1f %.1fx%.1f content %.1f,%.1f %.1fx%.1f",
				box.x1, box.y1, box.get_width(), box.get_height(),
				origin_x, origin_y, available_width, available_height);
			for (var child = this.first_child; child != null; child = child.get_next_sibling()) {
				float min_width, natural_width, min_height, natural_height;
				child.get_preferred_width(available_height, out min_width, out natural_width);
				var width = natural_width.clamp(min_width, available_width);
				child.get_preferred_height(width, out min_height, out natural_height);
				var height = natural_height.clamp(min_height, available_height);
				var child_box = Clutter.ActorBox();
				child_box.set_origin(origin_x, origin_y);
				child_box.set_size(width, height);
				var layout = child.layout_manager;
				if (layout != null && layout.rpc_lid == 0) {
					child.relay_allocation(child_box);
				}
				child.allocate(child_box);
			}
		}
	}
}
