/**
 * Client rebuild of a {@link Clutter.ActorBox} from x1, y1, x2, y2.
 */
namespace Shell
{
	internal class ActorBoxOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get {
				return typeof(Clutter.ActorBox);
			}
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			var box = (Clutter.ActorBox*) src.get_boxed();
			return OLLMrpc.args("dddd",
				(double) box.x1, (double) box.y1,
				(double) box.x2, (double) box.y2);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 4;
			var box = Clutter.ActorBox();
			box.x1 = (float) fields.get(index).get_double();
			box.y1 = (float) fields.get(index + 1).get_double();
			box.x2 = (float) fields.get(index + 2).get_double();
			box.y2 = (float) fields.get(index + 3).get_double();
			var v = GLib.Value(typeof(Clutter.ActorBox));
			v.set_boxed(box.copy());
			return v;
		}
	}

	[CCode (cname = "shell_actor_box_override_register")]
	public void actor_box_override_register()
	{
		OLLMrpc.Bin.TypeOverride.register(new ActorBoxOverride());
	}
}
