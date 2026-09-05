		/**
		 * Client-local laters — {@code GSourceFunc} is not RPC-marshallable.
		 * Use Vala {@link GLib.SourceFunc} (owned): codegen supplies the C
		 * {@code user_data} / {@code GDestroyNotify} that GIR/GJS expect.
		 * {@code when} is ignored (stock phases need a live stage redraw).
		 */
		private class LaterEntry
		{
			public uint source_id;
			public GLib.SourceFunc func;
		}

		private uint32 next_later_id = 1;
		private Gee.HashMap<uint32, LaterEntry> later_entries =
			new Gee.HashMap<uint32, LaterEntry>();

		public uint32 add(LaterType when, owned GLib.SourceFunc func)
		{
			/* when: stock BEFORE_REDRAW / idle; client has no stage redraw. */
			assert(when >= 0);
			var later_id = this.next_later_id++;
			if (later_id == 0) {
				later_id = this.next_later_id++;
			}
			var entry = new LaterEntry();
			entry.func = (owned) func;
			entry.source_id = GLib.Idle.add(() => {
				LaterEntry? cur;
				if (!this.later_entries.has_key(later_id)) {
					return GLib.Source.REMOVE;
				}
				cur = this.later_entries.get(later_id);
				bool keep = cur.func();
				if (!keep) {
					this.later_entries.unset(later_id);
				}
				return keep ? GLib.Source.CONTINUE : GLib.Source.REMOVE;
			});
			this.later_entries.set(later_id, entry);
			return later_id;
		}

		public void remove(uint32 later_id)
		{
			LaterEntry entry;
			if (!this.later_entries.unset(later_id, out entry)) {
				return;
			}
			if (entry.source_id != 0) {
				GLib.Source.remove(entry.source_id);
			}
			/* owned SourceFunc drops with entry — runs GJS destroy notify */
		}
