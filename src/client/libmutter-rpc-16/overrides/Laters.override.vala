		/**
		 * Client-local {@code GSourceFunc} table. Stock mutter runs
		 * {@link LaterType.before_redraw} from
		 * {@code ClutterStage::before-update}. Do not Idle or Timeout as a
		 * stand-in, and do not add a Runtime flush delegate.
		 *
		 * Queue + {@code schedule_update}. Subscribe {@code before-update};
		 * Runtime re-emits {@link OLLMrpc.Notification.args} onto the
		 * client Stage. {@code Clutter-Frame} is {@link OLLMrpc.Bin.register}ed
		 * (opaque boxed). Do not Idle.
		 */
		private class LaterEntry
		{
			public GLib.SourceFunc func;
			public LaterType when;
			public bool dead;

			~LaterEntry()
			{
				unowned GLib.Closure closure = closure_ref(this.func);
				if (closure == null) {
					return;
				}
				var left = *((uint*) closure) & 0x7fff;
				while (left > 2) {
					closure.unref();
					left--;
				}
				closure.unref();
			}
		}

		private static int add_depth;
		private int redraw_depth;
		private bool redraw_pending;
		private uint32 next_later_id = 1;
		private Gee.HashMap<uint32, LaterEntry> later_entries {
			get; set; default = new Gee.HashMap<uint32, LaterEntry>();
		}
		private Gee.ArrayList<uint32> pending_ids {
			get; set; default = new Gee.ArrayList<uint32>();
		}
		private Gee.ArrayList<uint32> invoking {
			get; set; default = new Gee.ArrayList<uint32>();
		}
		private bool stage_hooked = false;

		[CCode (cname = "gsr_closure_ref")]
		private static extern unowned GLib.Closure closure_ref(GLib.SourceFunc func);

		public uint32 add(LaterType when, owned GLib.SourceFunc func)
		{
			assert(when >= 0);
			add_depth++;
			/* A second add can start before this one returns. GJS then
			 * releases the inner callback. Hold it once per unfinished
			 * add. Leftover holds go when the entry is freed, after the
			 * callback has returned. */
			for (var i = 0; i < add_depth - 1; i++) {
				unowned GLib.Closure closure = closure_ref(func);
				if (closure == null) {
					break;
				}
			}
			var later_id = this.next_later_id++;
			if (later_id == 0) {
				later_id = this.next_later_id++;
			}
			var entry = new LaterEntry();
			entry.func = (owned) func;
			entry.when = when;
			this.later_entries.set(later_id, entry);
			this.pending_ids.add(later_id);
			this.ensure_before_update();
			this.schedule_stage_update();
			add_depth--;
			return later_id;
		}

		private Clutter.Stage? lookup_stage()
		{
			var display = Meta.get_display();
			if (display == null) {
				return null;
			}
			var compositor = display.get_compositor();
			if (compositor == null) {
				return null;
			}
			return compositor.get_stage();
		}

		private void ensure_before_update()
		{
			if (this.stage_hooked) {
				return;
			}
			var stage = this.lookup_stage();
			if (stage == null) {
				return;
			}
			Gsr.Client.Rpc.ensure_signal_subscribe(
				stage, "before-update");
			stage.signal_before_update.connect((view, frame) => {
				this.run_before_redraw();
			});
			this.stage_hooked = true;
		}

		private void run_before_redraw()
		{
			/* before-update is delivered on the RPC reply of a later that
			 * is already running. Running the queue from there re-enters
			 * WorkspaceTracker._checkWorkspaces, which appends a workspace
			 * on every entry. Finish this pass, run once more for laters
			 * queued during it, and leave a further pass to the next frame. */
			if (this.redraw_depth > 0) {
				this.redraw_pending = true;
				return;
			}
			this.redraw_depth++;
			this.dispatch_before_redraw();
			if (this.redraw_pending) {
				this.redraw_pending = false;
				this.dispatch_before_redraw();
			}
			if (this.redraw_pending) {
				this.redraw_pending = false;
				this.schedule_stage_update();
			}
			this.redraw_depth--;
		}

		private void dispatch_before_redraw()
		{
			var snapshot = new Gee.ArrayList<uint32>();
			snapshot.add_all(this.pending_ids);
			foreach (var later_id in snapshot) {
				if (!this.later_entries.has_key(later_id)) {
					continue;
				}
				var entry = this.later_entries.get(later_id);
				if (entry.dead || entry.when != LaterType.before_redraw) {
					continue;
				}
				this.invoking.add(later_id);
				var again = entry.func();
				this.invoking.remove(later_id);
				if (this.invoking.contains(later_id) && again) {
					continue;
				}
				if (this.invoking.contains(later_id)) {
					entry.dead = true;
					continue;
				}
				if (again && !entry.dead) {
					continue;
				}
				if (this.later_entries.unset(later_id)) {
					this.pending_ids.remove(later_id);
				}
			}
		}

		private void schedule_stage_update()
		{
			var stage = this.lookup_stage();
			if (stage == null) {
				return;
			}
			stage.schedule_update();
		}

		public void remove(uint32 later_id)
		{
			if (!this.later_entries.has_key(later_id)) {
				return;
			}
			if (this.invoking.contains(later_id)) {
				this.later_entries.get(later_id).dead = true;
				return;
			}
			if (!this.later_entries.unset(later_id)) {
				return;
			}
			this.pending_ids.remove(later_id);
		}
