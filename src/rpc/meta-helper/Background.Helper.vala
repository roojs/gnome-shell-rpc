/**
 * Delivers {@link Meta.Background} Override RPC (plan 0.5.7 C2).
 *
 * Wire prefix ''Meta-Helper-Background''.
 */
namespace GnomeShellRpc.Rpc.MetaHelper
{
	public class BackgroundHelper : GLib.Object
	{
		public static void register()
		{
			OLLMrpc.Request.add_class(
				"Meta-Helper-Background", typeof(BackgroundHelper),
				"set_file", "si",
				null
			);
			OLLMrpc.Request.register_live(
				"Meta-Helper-Background",
				new BackgroundHelper()
			);
		}

		public void set_file(
			OLLMrpc.Request request,
			string uri,
			int style
		)
		{
			var background = (Meta.Background) request.connection.leases.get((int) request.lease_id);
			GLib.File? file = null;
			if (uri != "") {
				file = GLib.File.new_for_uri(uri);
			}
			background.set_file(file, (GDesktop.BackgroundStyle) style);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
