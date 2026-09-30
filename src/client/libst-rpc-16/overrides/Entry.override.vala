		/**
		 * Stock searchController connects {@code text-changed} on this
		 * Clutter.Text. The GJS wrap requests the live subscribe.
		 *
		 * {@code key-press-event} carries a {@link Clutter.Event}. That type
		 * is packed by {@link Shell.ClutterEventOverride}, not as a bin value.
		 */
		public Clutter.Text clutter_text {
			[CCode (cname = "st_entry_get_clutter_text")]
			owned get {
				var response = GnomeShellRpc.call_value("St-Entry.get_clutter_text", this);
				return (Clutter.Text) response.retval.get_object();
			}
		}
