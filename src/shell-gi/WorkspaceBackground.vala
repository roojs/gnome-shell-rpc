/**
 * Owned {@link Shell.WorkspaceBackground} — stock
 * shell-workspace-background (0.7.7 T-039).
 *
 * Class allocate sizes the first child and grandchild so the wallpaper
 * actor is not 0×0. GJS workspace.js adds those children.
 */
namespace Shell
{
	public class WorkspaceBackground : St.Widget
	{
		public int monitor_index { get; construct set; default = 0; }
		public double state_adjustment_value { get; set; default = 0; }

		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var t = this.get_type();
			if (t != typeof(WorkspaceBackground) && !t.name().has_prefix("Gjs_")) {
				return;
			}
			var response = GnomeShellRpc.call_value("St-Widget.new");
			var stub = response.retval.get_object() as OLLMrpc.Live.Interface;
			this.rpc_lid = stub.rpc_lid;
		}

		public override void allocate_vfunc(Clutter.ActorBox box)
		{
			var width = 0f;
			var height = 0f;
			box.get_size(out width, out height);
			if (width <= 0 || height <= 0) {
				this.set_allocation(box);
				return;
			}

			var scaled_height = height - 12 * 2 * St.ThemeContext.get_for_stage((Clutter.Stage) this.get_stage()).scale_factor;
			var scaled_width = (scaled_height / height) * width;
			var content_box = Clutter.ActorBox();
			content_box.init_rect(
				box.x1 + (width - scaled_width) / 2,
				box.y1 + (height - scaled_height) / 2,
				scaled_width, scaled_height);

			Clutter.ActorBox my_box;
			box.interpolate(content_box, this.state_adjustment_value, out my_box);
			this.set_allocation(my_box);

			this.get_theme_node().get_content_box(my_box, out content_box);
			this.first_child.allocate(content_box);

			Mtk.Rectangle work;
			Global.get().workspace_manager.get_workspace_by_index(0)
				.get_work_area_for_monitor(this.monitor_index, out work);
			Mtk.Rectangle mon;
			Global.get().display.get_monitor_geometry(this.monitor_index, out mon);

			var x_scale = content_box.get_width() / work.width;
			var y_scale = content_box.get_height() / work.height;
			content_box.set_origin((mon.x - work.x) * x_scale, (mon.y - work.y) * y_scale);
			content_box.set_size(
				content_box.get_width() + (mon.width - work.width) * x_scale,
				content_box.get_height() + (mon.height - work.height) * y_scale);
			this.first_child.first_child.allocate(content_box);
		}
	}
}
