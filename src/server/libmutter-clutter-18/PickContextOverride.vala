/**
 * Server pack of a {@link global::Clutter.PickContext}.
 *
 * Opaque boxed record, not a GObject. The {@code pick} signal argument
 * has no wire schema. Pack nothing. The client handler ignores it.
 */
namespace Gsr.Server.Clutter
{
	public class PickContextOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get {
				return typeof(global::Clutter.PickContext);
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
			return GLib.Value(typeof(global::Clutter.PickContext));
		}
	}
}
