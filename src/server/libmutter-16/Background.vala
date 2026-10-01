/**
 * Delivers {@link global::Meta.Background} Override RPC (plan 0.5.7 C2).
 *
 * Wire prefix ''Gsr-Mutter-Background''. {@code create} returns lease id in
 * {@link OLLMrpc.Response.args} — not {@code retval} — so the client
 * {@code construct} can set {@code rpc_lid} without re-entering
 * {@code Background} construction via a live retval decode.
 */
namespace Gsr.Server.Meta
{
	public class Background : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Mutter-Background", typeof(Background),
				"create", "o",
				"set_file", "si",
				null
			);
			OLLMrpc.Request.register_live("Gsr-Mutter-Background", new Background());
		}

		/**
		 * ''Gsr-Mutter-Background.create'' — create compositor background.
		 *
		 * @param request inbound RPC
		 * @param display compositor display (wire ''o'' / lease)
		 */
		public void create(
			OLLMrpc.Request request,
			global::Meta.Display display
		) {
			var background = new global::Meta.Background(display);
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
			var background = (global::Meta.Background) request.connection.leases.get(
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
