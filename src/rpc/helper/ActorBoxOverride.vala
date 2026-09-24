/**
 * {@link Clutter.ActorBox} as x1, y1, x2, y2.
 *
 * {@code notify::allocation} otherwise writes the raw box and
 * {@code StreamValue} resets the connection.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class ActorBoxOverride : OLLMrpc.Bin.TypeOverride
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
			var box = ActorBoxOverride.box_new(
				(float) fields.get(index).get_double(),
				(float) fields.get(index + 1).get_double(),
				(float) fields.get(index + 2).get_double(),
				(float) fields.get(index + 3).get_double());
			var v = GLib.Value(typeof(Clutter.ActorBox));
			v.take_boxed(box);
			return v;
		}

		[CCode (cname = "clutter_actor_box_new")]
		private static extern Clutter.ActorBox* box_new(float x1, float y1, float x2, float y2);
	}
}
