		/**
		 * Stock searchController connects {@code text-changed} on this
		 * Clutter.Text. GJS {@code connect()} is local; without a live
		 * subscribe the server emit never reaches the client (empty
		 * overview results while the field still fills). After the lease
		 * exists — not in Text construct (nested RPC during parse hung).
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
				var text = (Clutter.Text) response.retval.get_object();
				GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(
					text, "text-changed");
				GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(
					text, "key-focus-in");
				GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(
					text, "key-focus-out");
				return text;
			}
		}
