/**
 * {@link Graphene.Point} as x, y.
 *
 * A window actor's pivot notify otherwise writes the raw boxed
 * point and {@code StreamValue} resets the connection.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class GraphenePointOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get {
				return typeof(Graphene.Point);
			}
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			var point = (Graphene.Point*) src.get_boxed();
			return OLLMrpc.args("dd", (double) point.x, (double) point.y);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 2;
			var point = (Graphene.Point*) GLib.malloc0(sizeof(Graphene.Point));
			GraphenePointOverride.point_init(
				point,
				(float) fields.get(index).get_double(),
				(float) fields.get(index + 1).get_double());
			var v = GLib.Value(typeof(Graphene.Point));
			v.take_boxed(point);
			return v;
		}

		[CCode (cname = "graphene_point_init")]
		private static extern unowned Graphene.Point* point_init(
			Graphene.Point* point,
			float x,
			float y
		);
	}
}
