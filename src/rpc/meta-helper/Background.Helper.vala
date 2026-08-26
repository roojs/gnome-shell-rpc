/**
 * Delivers {@link Meta.Background} Override RPC (plan 0.5.7 C2).
 */
namespace GnomeShellRpc.Rpc.MetaHelper
{
	public class BackgroundHelper : GLib.Object
	{
		public static void register_all()
		{
		}

		public static void set_file(
			Meta.Background background,
			string uri,
			GDesktop.BackgroundStyle style
		)
		{
			GLib.File? file = null;
			if (uri != "") {
				file = GLib.File.new_for_uri(uri);
			}
			background.set_file(file, style);
		}
	}
}
