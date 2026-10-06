/**
 * Client rebuild of a {@link Graphene.Size} from width, height.
 */
namespace Shell
{
	internal class GrapheneSizeOverride : OLLMrpc.Bin.TypeOverride
	{
		[CCode (cname = "graphene_size_init", cheader_filename = "graphene.h")]
		private static extern unowned Graphene.Size* graphene_size_init(
			Graphene.Size* size, float width, float height);

		public override GLib.Type override_type {
			get { return typeof(Graphene.Size); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
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
			graphene_size_init(size,
				(float) fields.get(index).get_double(),
				(float) fields.get(index + 1).get_double());
			var v = GLib.Value(typeof(Graphene.Size));
			v.take_boxed(size);
			return v;
		}

		internal static void register()
		{
			OLLMrpc.Bin.TypeOverride.register(new GrapheneSizeOverride());
		}
	}
}
