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
		private static Gee.HashMap<int, GLib.Cancellable>? twins = null;

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
			if (CancellableBridge.twins == null) {
				CancellableBridge.twins = new Gee.HashMap<int, GLib.Cancellable>();
			}
			var key = (int) id;
			if (!CancellableBridge.twins.has_key(key)) {
				CancellableBridge.twins.set(key, new GLib.Cancellable());
			}
			return CancellableBridge.twins.get(key);
		}

		public void cancel(OLLMrpc.Request request, uint64 id)
		{
			if (id == 0 || CancellableBridge.twins == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var key = (int) id;
			if (CancellableBridge.twins.has_key(key)) {
				CancellableBridge.twins.get(key).cancel();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
