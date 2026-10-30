/**
 * {@code AuthRequest.finish} drops its last owner inside {@code finished}.
 * Touching the request after that signal is a use-after-free.
 */
namespace PolkitRequestFinishHold
{
	/**
	 * One request. {@code finished} is what the async auth method waits on.
	 */
	public class Request : GLib.Object
	{
		public int cookie;

		/**
		 * Fired when the dialog calls {@code complete}.
		 */
		public signal void finished();

		/**
		 * Emit {@code finished}, then write a field. The handler has
		 * dropped the only other reference.
		 */
		public void finish_bad()
		{
			this.finished();
			this.cookie = 7;
		}

		/**
		 * Same sequence, with this instance kept alive across the signal.
		 */
		public void finish_held()
		{
			var held = this;
			held.finished();
			held.cookie = 7;
		}
	}

	/**
	 * Owns the request the way {@code current_request} does, and clears
	 * that owner from the {@code finished} handler.
	 */
	public class Driver : GLib.Object
	{
		public Request? current;

		/**
		 * Run one finish. {@code hold} selects the kept-alive path.
		 */
		public void run(bool hold)
		{
			this.current = new Request();
			this.current.finished.connect(() => {
				this.current = null;
			});
			if (!hold) {
				this.current.finish_bad();
				return;
			}
			this.current.finish_held();
		}
	}

	/**
	 * {@code bad} is expected to abort under AddressSanitizer.
	 * {@code held} must return.
	 */
	public static int main(string[] args)
	{
		var hold = args.length > 1 && args[1] == "held";
		var driver = new Driver();
		driver.run(hold);
		if (!hold) {
			stdout.printf("FAIL polkit-request-finish-hold: bad returned\n");
			return 1;
		}
		stdout.printf("PASS polkit-request-finish-hold: held\n");
		return 0;
	}
}
