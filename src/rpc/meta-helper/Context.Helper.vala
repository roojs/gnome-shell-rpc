/**
 * Delivers {@link Meta.Context} Override RPC (plan 0.5.7 C3).
 */
namespace GnomeShellRpc.Rpc.MetaHelper
{
	public class ContextHelper : GLib.Object
	{
		public static void register_all()
		{
		}

		public static void terminate_with_error(
			Meta.Context context,
			string domain,
			int code,
			string message
		)
		{
			var error = new GLib.Error.literal(
				GLib.Quark.from_string(domain),
				code,
				message
			);
			context.terminate_with_error(error);
		}
	}
}
