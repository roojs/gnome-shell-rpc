/**
 * Owned {@code Shell.Stack} — stock {@code shell-stack.c}.
 *
 * Z-axis container: children share the content box; preferred size is the
 * max of children (with theme-node padding).
 */
namespace Shell
{
	public class Stack : St.Widget
	{
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var t = this.get_type();
			if (t != typeof(Stack) && !t.name().has_prefix("Gjs_")) {
				return;
			}
			var response = GnomeShellRpc.call_value("St-Widget.new", null);
			var stub = response.retval.get_object() as OLLMrpc.Live.Handle;
			this.rpc_lid = stub.rpc_lid;
		}

		public override void get_preferred_width_vfunc(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			var theme_node = this.get_theme_node();
			var for_h = for_height;
			theme_node.adjust_for_height(ref for_h);

			var min = 0f;
			var natural = 0f;
			var first = true;
			for (var child = this.first_child; child != null; child = child.get_next_sibling()) {
				float child_min;
				float child_natural;
				child.get_preferred_width(for_h, out child_min, out child_natural);
				if (first) {
					first = false;
					min = child_min;
					natural = child_natural;
					continue;
				}
				if (child_min > min) {
					min = child_min;
				}
				if (child_natural > natural) {
					natural = child_natural;
				}
			}

			min_width_p = min;
			natural_width_p = natural;
			theme_node.adjust_preferred_width(ref min_width_p, ref natural_width_p);
		}

		public override void get_preferred_height_vfunc(
			float for_width,
			out float min_height_p,
			out float natural_height_p
		) {
			var theme_node = this.get_theme_node();
			var for_w = for_width;
			theme_node.adjust_for_width(ref for_w);

			var min = 0f;
			var natural = 0f;
			var first = true;
			for (var child = this.first_child; child != null; child = child.get_next_sibling()) {
				float child_min;
				float child_natural;
				child.get_preferred_height(for_w, out child_min, out child_natural);
				if (first) {
					first = false;
					min = child_min;
					natural = child_natural;
					continue;
				}
				if (child_min > min) {
					min = child_min;
				}
				if (child_natural > natural) {
					natural = child_natural;
				}
			}

			min_height_p = min;
			natural_height_p = natural;
			theme_node.adjust_preferred_height(ref min_height_p, ref natural_height_p);
		}

		public override void allocate_vfunc(Clutter.ActorBox box)
		{
			this.set_allocation(box);

			Clutter.ActorBox content_box;
			this.get_theme_node().get_content_box(box, out content_box);

			for (var child = this.first_child; child != null; child = child.get_next_sibling()) {
				child.allocate(content_box);
			}
		}

		public override bool navigate_focus(
			Clutter.Actor? from,
			St.DirectionType direction,
			bool wrap_around
		) {
			if (this.can_focus) {
				if (from != null && this.contains(from)) {
					return false;
				}
				if (!this.mapped) {
					return false;
				}
				this.grab_key_focus();
				return true;
			}

			var top_actor = this.last_child;
			while (top_actor != null && !top_actor.is_visible()) {
				top_actor = top_actor.get_previous_sibling();
			}
			var top_widget = top_actor as St.Widget;
			if (top_widget == null) {
				return false;
			}
			return top_widget.navigate_focus(from, direction, false);
		}
	}
}
