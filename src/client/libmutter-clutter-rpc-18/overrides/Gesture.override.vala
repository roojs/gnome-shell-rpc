		private Event? point_event_cache;

		/**
		 * Stock {@code clutter_gesture_get_point_event}. The compositor
		 * returns the compact event fields; keep the rebuilt event alive
		 * until the next call.
		 */
		[CCode (cname = "clutter_gesture_get_point_event")]
		public unowned Event? get_point_event(int point_index)
		{
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Clutter-PressGesture.get_point_event", this,
				OLLMrpc.args("i", point_index));
			if (response.args.size < 5) {
				return null;
			}
			this.point_event_cache = Clutter.event_from_values(response.args);
			return this.point_event_cache;
		}
