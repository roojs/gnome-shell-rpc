/**
 * JS {@code St.DrawingArea} subclass. Preferred size is the
 * client vfunc. Allocate stays the stock drawing-area allocate,
 * which emits {@code repaint}.
 */
namespace Gsr.Server.St
{
	public class DrawingAreaActor : global::St.DrawingArea
	{
		public Gee.HashMap<int, OLLMrpc.Live.Hook> vfuncs {
			get; set; default = new Gee.HashMap<int, OLLMrpc.Live.Hook>();
		}
		public Gee.HashMap<int, string> method_names {
			get; set; default = new Gee.HashMap<int, string>();
		}
		public string? client_type_name;

		public override void get_preferred_width(
			float for_height,
			out float min_width_p,
			out float natural_width_p
		) {
			if (!this.report_preferred(
					"get_preferred_width", for_height,
					out min_width_p, out natural_width_p)) {
				base.get_preferred_width(
					for_height, out min_width_p, out natural_width_p);
			}
		}

		public override void get_preferred_height(
			float for_width,
			out float min_height_p,
			out float natural_height_p
		) {
			if (!this.report_preferred(
					"get_preferred_height", for_width,
					out min_height_p, out natural_height_p)) {
				base.get_preferred_height(
					for_width, out min_height_p, out natural_height_p);
			}
		}

		bool report_preferred(
			string name,
			float for_size,
			out float min_p,
			out float natural_p
		) {
			min_p = 0.0f;
			natural_p = 0.0f;
			var vfunc_id = OLLMrpc.Gi.vfunc_offset("Clutter", "Actor", name);
			if (!this.vfuncs.has_key(vfunc_id)) {
				return false;
			}
			var hook = this.vfuncs.get(vfunc_id);
			hook.emit(OLLMrpc.args("td",
				hook.connection.export(this), (double) for_size));
			var args = hook.reply_args;
			if ((args.size == 1 && args.get(0).holds(typeof(OLLMrpc.Error)))
					|| args.size < 2) {
				return false;
			}
			min_p = (float) args.get(0).get_double();
			natural_p = (float) args.get(1).get_double();
			GLib.debug("preferred %s type=%s min=%g nat=%g",
				name,
				this.client_type_name != null ? this.client_type_name : "?",
				min_p, natural_p);
			return true;
		}
	}
}
