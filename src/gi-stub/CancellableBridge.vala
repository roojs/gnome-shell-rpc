/**
 * Client-side paired {@link GLib.Cancellable} for Override RPC (plan 0.5.7).
 *
 * Phase 1: register returns 0; cancel forward not wired.
 */
namespace GnomeShellRpc.GiStub
{
	public class CancellableBridge : GLib.Object
	{
		/**
		 * Register a client cancellable; returns wire id (0 = null / none).
		 */
		public static uint64 register(GLib.Cancellable? cancellable)
		{
			if (cancellable == null) {
				return 0;
			}
			return 0;
		}
	}
}
