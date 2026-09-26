/**
 * Stores {@link GLib.SourceFunc} callbacks the way {@code Meta.Laters} does.
 * {@link Holder} calls one back after the caller returns.
 * {@link Later} queues several and runs them from {@link Later.poke}, which
 * can re-enter while a callback is still on the stack.
 */
namespace LaterCallbackHold
{
	public class Holder : GLib.Object
	{
		private GLib.SourceFunc? func;

		public void store (owned GLib.SourceFunc func)
		{
			this.func = (owned) func;
		}

		public bool fire ()
		{
			if (this.func == null) {
				return false;
			}
			return this.func ();
		}
	}

	private class LaterEntry : GLib.Object
	{
		public GLib.SourceFunc func;
	}

	public class Later : GLib.Object
	{
		private static Later? pinned;
		private uint next_id = 1;
		private GLib.HashTable<uint, LaterEntry> pending;
		private uint[] order = {};
		private GLib.SourceFunc? during_add;
		private bool in_during_add;

		construct
		{
			this.pending = new GLib.HashTable<uint, LaterEntry> (GLib.direct_hash, GLib.direct_equal);
		}

		/**
		 * Called from {@link add} before {@link add} returns, so a nested
		 * {@link add} of another callback is still inside the outer call.
		 */
		public void set_during_add (owned GLib.SourceFunc func)
		{
			this.during_add = (owned) func;
		}

		public uint add (owned GLib.SourceFunc func)
		{
			var id = this.next_id++;
			var entry = new LaterEntry ();
			entry.func = (owned) func;
			this.pending.insert (id, entry);
			this.order += id;
			if (this.during_add != null && !this.in_during_add) {
				this.in_during_add = true;
				this.during_add ();
				this.in_during_add = false;
			}
			return id;
		}

		public void remove (uint id)
		{
			this.pending.remove (id);
			uint[] kept = {};
			foreach (var existing in this.order) {
				if (existing != id) {
					kept += existing;
				}
			}
			this.order = kept;
		}

		/**
		 * Keep the GObject after GJS drops the wrapper, so a later
		 * {@link poke} still has a C object to call.
		 */
		public void pin ()
		{
			Later.pinned = this;
		}

		public static Later? get_pinned ()
		{
			return Later.pinned;
		}

		/**
		 * Sync call that runs every pending callback before it returns.
		 * A callback may {@link poke} again, or {@link remove} its own id.
		 */
		public void poke ()
		{
			var keys = this.order;
			foreach (var id in keys) {
				var entry = this.pending.lookup (id);
				if (entry == null) {
					continue;
				}
				entry.ref ();
				stderr.printf ("poke id=%u\n", id);
				stderr.flush ();
				var again = entry.func ();
				stderr.printf ("poke id=%u again=%d\n", id, again ? 1 : 0);
				stderr.flush ();
				if (!again) {
					this.pending.remove (id);
				}
				entry.unref ();
			}
		}
	}
}
