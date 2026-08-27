/**
 * Delivers {@link Meta.Background} Override RPC (plan 0.5.7 C2).
 *
 * Wire prefix ''Helper-Background''.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Background : GLib.Object
	{
		public static void register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Background", typeof(Background),
				"set_file", "si",
				null
			);
			OLLMrpc.Request.register_live("Helper-Background", new Background());
		}

		public void set_file(
			OLLMrpc.Request request,
			string uri,
			int style
		) {
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
