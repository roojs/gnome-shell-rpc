/**
 * Server-side paired {@link GLib.Cancellable} for Override RPC (plan 0.5.7).
 *
 * Wire prefix {@code RPC-Cancellable}. Twins are created on first
 * {@link lookup} and cancelled via {@link cancel}.
 */
namespace GnomeShellRpc.Rpc
{
	public class CancellableBridge : GLib.Object
	{
		private static Gee.HashMap<uint64?, GLib.Cancellable> twins =
			new Gee.HashMap<uint64?, GLib.Cancellable>();

		public static void register()
		{
			OLLMrpc.Request.add_class(
				"RPC-Cancellable", typeof(CancellableBridge),
				"cancel", "t",
				null
			);
			OLLMrpc.Request.register(
				"RPC-Cancellable",
				new CancellableBridge()
			);
		}

		public static GLib.Cancellable? lookup(uint64 id)
		{
			if (id == 0) {
				return null;
			}
			if (!CancellableBridge.twins.has_key(id)) {
				CancellableBridge.twins.set(id, new GLib.Cancellable());
			}
			return CancellableBridge.twins.get(id);
		}

		public void cancel(OLLMrpc.Request request, uint64 id)
		{
			if (id != 0 && CancellableBridge.twins.has_key(id)) {
				CancellableBridge.twins.get(id).cancel();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
