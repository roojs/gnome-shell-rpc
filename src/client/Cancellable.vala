/**
 * Client-side paired {@link GLib.Cancellable} for Override RPC (plan 0.5.7).
 *
 * Assigns a wire id and forwards {@link GLib.Cancellable.cancel} to
 * {@code Server-Cancellable.cancel} on the server.
 */
namespace Gsr.Client
{
	public class Cancellable : GLib.Object
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
			if (Cancellable.watch_ids == null) {
				Cancellable.watch_ids = new Gee.HashMap<int, ulong>();
			}
			var id = Cancellable.next_id++;
			var watch = cancellable.connect((c) => {
				Gsr.Client.Rpc.call_value(
					"Server-Cancellable.cancel",
					null,
					OLLMrpc.args("t", id)
				);
			});
			Cancellable.watch_ids.set((int) id, watch);
			return id;
		}
	}
}
