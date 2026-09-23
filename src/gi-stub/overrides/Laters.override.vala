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
		}

		private uint32 next_later_id = 1;
		private Gee.HashMap<uint32, LaterEntry> later_entries {
			get; set; default = new Gee.HashMap<uint32, LaterEntry>();
		}
		private Gee.ArrayList<uint32> pending_ids {
			get; set; default = new Gee.ArrayList<uint32>();
		}
		private bool stage_hooked = false;

		public uint32 add(LaterType when, owned GLib.SourceFunc func)
		{
			assert(when >= 0);
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
			GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(
				stage, "before-update");
			stage.signal_before_update.connect((view, frame) => {
				this.run_before_redraw();
			});
			this.stage_hooked = true;
		}

		private void run_before_redraw()
		{
			var snapshot = new Gee.ArrayList<uint32>();
			snapshot.add_all(this.pending_ids);
			foreach (var later_id in snapshot) {
				if (!this.later_entries.has_key(later_id)) {
					continue;
				}
				var entry = this.later_entries.get(later_id);
				if (entry.when != LaterType.before_redraw) {
					continue;
				}
				var again = entry.func();
				if (!again) {
					this.later_entries.unset(later_id);
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
			if (!this.later_entries.unset(later_id)) {
				return;
			}
			this.pending_ids.remove(later_id);
		}
