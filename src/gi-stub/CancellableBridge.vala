/**
 * Client-side paired {@link GLib.Cancellable} for Override RPC (plan 0.5.7).
 *
 * Assigns a wire id and forwards {@link GLib.Cancellable.cancel} to
 * {@code RPC-Cancellable.cancel} on the server.
 */
namespace GnomeShellRpc.GiStub
{
	public class CancellableBridge : GLib.Object
	{
		private static uint64 next_id = 1;
		private static Gee.HashMap<int, ulong>? watch_ids = null;

		/**
		 * Register a client cancellable; returns wire id (0 = null / none).
		 */
		public static uint64 register(GLib.Cancellable? cancellable)
		{
			if (cancellable == null) {
				return 0;
			}
			if (CancellableBridge.watch_ids == null) {
				CancellableBridge.watch_ids = new Gee.HashMap<int, ulong>();
			}
			var id = CancellableBridge.next_id++;
			var watch = cancellable.connect((c) => {
				GnomeShellRpc.GiStub.Runtime.call_values(
					"RPC-Cancellable.cancel",
					null,
					OLLMrpc.args("t", id)
				);
			});
			CancellableBridge.watch_ids.set((int) id, watch);
			return id;
		}
	}
}
