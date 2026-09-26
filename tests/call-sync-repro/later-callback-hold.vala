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

		public void store(owned GLib.SourceFunc func)
		{
			this.func = (owned) func;
		}

		public bool fire()
		{
			if (this.func == null) {
				return false;
			}
			return this.func();
		}
	}

	private class LaterEntry : GLib.Object
	{
		public GLib.SourceFunc func;
		public bool drop_surplus;
		public bool dead;

		[CCode (cname = "later_callback_hold_unref_surplus")]
		private static extern void unref_surplus(GLib.SourceFunc func);

		~LaterEntry()
		{
			if (this.drop_surplus) {
				unref_surplus(this.func);
			}
		}
	}

	public class Later : GLib.Object
	{
		private static Later? pinned;
		private uint next_id = 1;
		private GLib.HashTable<uint, LaterEntry> pending;
		private uint[] order = {};
		private GLib.SourceFunc? during_add;
		private int during_nest_limit = 1;
		private int during_nest;
		private int guard;
		private int add_depth;
		private bool during_deferred;
		private uint[] invoking = {};

		[CCode (cname = "later_callback_hold_ref_source_func")]
		private static extern void ref_source_func(GLib.SourceFunc func, int times);

		[CCode (cname = "later_callback_hold_source_func_refs")]
		private static extern int source_func_refs(GLib.SourceFunc func);

		[CCode (cname = "later_callback_hold_watch_source_func")]
		private static extern void watch_source_func(GLib.SourceFunc func);

		[CCode (cname = "later_callback_hold_live_closures")]
		public static extern int live_closures();

		construct
		{
			this.pending = new GLib.HashTable<uint, LaterEntry>(GLib.direct_hash, GLib.direct_equal);
		}

		/**
		 * Called from {@link add} before {@link add} returns, so a nested
		 * {@link add} of another callback is still inside the outer call.
		 */
		public void set_during_add(owned GLib.SourceFunc func)
		{
			this.during_add = (owned) func;
		}

		/**
		 * 0: no guard. 1: one extra closure ref per outer {@link add} still
		 * on the stack. 2: run {@link set_during_add} after {@link add}
		 * returns. 3: a single extra ref on a nested callback.
		 */
		public void set_guard(int guard)
		{
			this.guard = guard;
		}

		public void set_during_nest_limit(int limit)
		{
			this.during_nest_limit = limit;
		}

		public uint add(owned GLib.SourceFunc func)
		{
			this.add_depth++;
			if (this.add_depth > 1 && (this.guard == 1 || this.guard == 3 || this.guard == 4)) {
				var times = this.guard == 3 ? 1 : this.add_depth - 1;
				ref_source_func(func, times);
			}
			watch_source_func(func);
			var id = this.next_id++;
			var entry = new LaterEntry();
			entry.drop_surplus = this.guard == 4;
			entry.func = (owned) func;
			this.pending.insert(id, entry);
			this.order += id;
			var nest_now = this.during_add != null && this.during_nest < this.during_nest_limit;
			if (nest_now && this.guard == 2) {
				this.queue_during();
			} else if (nest_now) {
				this.during_nest++;
				this.during_add();
				this.during_nest--;
			}
			this.add_depth--;
			return id;
		}

		private void queue_during()
		{
			if (this.during_deferred) {
				return;
			}
			this.during_deferred = true;
			GLib.Idle.add(() => {
				this.during_deferred = false;
				this.run_deferred_during();
				return false;
			});
		}

		private void run_deferred_during()
		{
			if (this.during_add == null || this.during_nest >= this.during_nest_limit) {
				return;
			}
			this.during_nest++;
			this.during_add();
		}

		private bool is_invoking(uint id)
		{
			foreach (var existing in this.invoking) {
				if (existing == id) {
					return true;
				}
			}
			return false;
		}

		public void remove(uint id)
		{
			var entry = this.pending.lookup(id);
			if (entry != null && entry.drop_surplus && this.is_invoking(id)) {
				entry.dead = true;
				return;
			}
			this.pending.remove(id);
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
		public void pin()
		{
			Later.pinned = this;
		}

		public static Later? get_pinned()
		{
			return Later.pinned;
		}

		/**
		 * Sync call that runs every pending callback before it returns.
		 * A callback may {@link poke} again, or {@link remove} its own id.
		 */
		public void poke()
		{
			var keys = this.order;
			foreach (var id in keys) {
				var entry = this.pending.lookup(id);
				if (entry == null) {
					continue;
				}
				if (entry.dead) {
					continue;
				}
				entry.ref();
				stderr.printf("poke id=%u refs=%d\n", id, source_func_refs(entry.func));
				stderr.flush();
				this.invoking += id;
				var again = entry.func();
				uint[] still = {};
				var seen = false;
				foreach (var existing in this.invoking) {
					if (!seen && existing == id) {
						seen = true;
						continue;
					}
					still += existing;
				}
				this.invoking = still;
				stderr.printf("poke id=%u again=%d\n", id, again ? 1 : 0);
				stderr.flush();
				if (this.is_invoking(id)) {
					if (!again) {
						entry.dead = true;
					}
				} else if (!again || entry.dead) {
					this.pending.remove(id);
				}
				entry.unref();
			}
		}
	}
}
