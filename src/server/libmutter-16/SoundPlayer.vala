/**
 * Delivers {@link global::Meta.SoundPlayer} Override RPC (plan 0.5.7 C1).
 *
 * Wire prefix ''Gsr-Mutter-SoundPlayer''. Lease is the player;
 * {@link OLLMrpc.Request.register_live} keeps this singleton as ''this''.
 */
namespace Gsr.Server.Meta
{
	public class SoundPlayer : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Mutter-SoundPlayer", typeof(SoundPlayer),
				"play_from_file", "sst",
				"play_from_theme", "sst",
				null
			);
			OLLMrpc.Request.register_live("Gsr-Mutter-SoundPlayer", new SoundPlayer());
		}

		public void play_from_file(
			OLLMrpc.Request request,
			string uri,
			string description,
			uint64 cancel_id
		) {
			if (uri == "") {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					error = new OLLMrpc.Error((int) OLLMrpc.RpcErrorCode.INVALID_PARAMS, 
						"play_from_file requires a file uri"),
				});
				return;
			}
			var player = (global::Meta.SoundPlayer) request.connection.leases.get((int) request.lease_id);
			player.play_from_file(GLib.File.new_for_uri(uri), description,
				Gsr.Server.CancellableBridge.lookup(cancel_id));
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void play_from_theme(
			OLLMrpc.Request request,
			string name,
			string description,
			uint64 cancel_id
		) {
			var player = (global::Meta.SoundPlayer) request.connection.leases.get((int) request.lease_id);
			player.play_from_theme(name, description,
				Gsr.Server.CancellableBridge.lookup(cancel_id));
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
