		/**
		 * Stock searchController connects {@code text-changed} on this
		 * Clutter.Text. The GJS wrap requests the live subscribe.
		 *
		 * Do not subscribe {@code key-press-event}: {@code ClutterEvent} is
		 * Compact / not on the wire. Packing it resets the client
		 * ({@code unsupported bin value type 'ClutterEvent'}). Keys still
		 * insert on the server text; Helper {@code relay_event} emits locally.
		 */
		public Clutter.Text clutter_text {
			[CCode (cname = "st_entry_get_clutter_text")]
			owned get {
				var response = GnomeShellRpc.call_value(
					"St-Entry.get_clutter_text", this);
				return (Clutter.Text) response.retval.get_object();
			}
		}
