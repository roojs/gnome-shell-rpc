/**
 * Client side of a {@link Clutter.PickContext} signal argument.
 *
 * The server packs nothing. This consumes no fields and leaves a null
 * context. {@link Shell.Util.stop_pick} does not read it.
 */
namespace Shell
{
	internal class PickContextOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get {
				return typeof(Clutter.PickContext);
			}
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			return new Gee.ArrayList<GLib.Value?>();
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 0;
			var v = GLib.Value(typeof(Clutter.PickContext));
			v.set_object(null);
			return v;
		}

		internal static void register()
		{
			OLLMrpc.Bin.TypeOverride.register(new PickContextOverride());
		}
	}
}
