/**
 * Delivers {@link Meta.Background} Override RPC (plan 0.5.7 C2).
 *
 * Wire prefix ''Helper-Background''. {@code create} returns lease id in
 * {@link OLLMrpc.Response.args} — not {@code result} — so the client
 * {@code construct} can set {@code gsr-lease-id} without
 * {@code attach_lease} re-entering {@code Background} construction.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Background : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Background", typeof(Background),
				"create", "t",
				"set_file", "si",
				null
			);
			OLLMrpc.Request.register_live("Helper-Background",
				new Background());
		}

		/**
		 * ''Helper-Background.create'' — create compositor background.
		 *
		 * @param request inbound RPC
		 * @param display_lease lease id of {@link Meta.Display}
		 */
		public void create(
			OLLMrpc.Request request,
			uint64 display_lease
		) {
			var display = (Meta.Display) request.connection.leases.get(
				(int) display_lease
			);
			var background = new Meta.Background(display);
			var handle = (uint64) request.connection.export(background);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		public void set_file(
			OLLMrpc.Request request,
			string uri,
			int style
		) {
			var background = (Meta.Background) request.connection.leases.get(
				(int) request.lease_id
			);
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
