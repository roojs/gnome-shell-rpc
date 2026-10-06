/**
 * {@link Graphene.Size} as width, height.
 *
 * A layout notify otherwise writes the raw boxed size and
 * {@code StreamValue} resets the connection.
 */
namespace Gsr.Server.Clutter
{
	public class GrapheneSizeOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get {
				return typeof(Graphene.Size);
			}
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return OLLMrpc.args("dd", 0.0, 0.0);
			}
			unowned var size = (Graphene.Size*) src.get_boxed();
			return OLLMrpc.args("dd",
				(double) size.width, (double) size.height);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 2;
			var size = (Graphene.Size*) GLib.malloc0(sizeof(Graphene.Size));
			GrapheneSizeOverride.size_init(
				size,
				(float) fields.get(index).get_double(),
				(float) fields.get(index + 1).get_double());
			var v = GLib.Value(typeof(Graphene.Size));
			v.take_boxed(size);
			return v;
		}

		[CCode (cname = "graphene_size_init")]
		private static extern unowned Graphene.Size* size_init(
			Graphene.Size* size,
			float width,
			float height
		);
	}
}
