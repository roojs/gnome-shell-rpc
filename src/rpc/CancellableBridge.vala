/**
 * Server-side paired {@link GLib.Cancellable} for Override RPC (plan 0.5.7).
 *
 * Phase 1: scaffold only — not registered in {@link Server.start}.
 */
namespace GnomeShellRpc.Rpc
{
	public class CancellableBridge : GLib.Object
	{
		public static GLib.Cancellable? lookup(uint64 id)
		{
			if (id == 0) {
				return null;
			}
			return null;
		}

		public static void cancel(uint64 id)
		{
			if (id == 0) {
				return;
			}
		}

		public static void register_all()
		{
		}
	}
}
