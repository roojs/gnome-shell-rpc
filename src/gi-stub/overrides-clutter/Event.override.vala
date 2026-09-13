		/**
		 * Client-local fields for Live.Hook event relay (no ClutterEvent
		 * lease — Event is boxed on the server). When {@code local_valid},
		 * accessors skip RPC.
		 */
		private bool local_valid;
		private EventType local_type;
		private float local_x;
		private float local_y;
		private uint32 local_button;

		/**
		 * Build a stub Event from packed Live.Hook args (type, coords, button).
		 */
		public static Event from_local(
			EventType type,
			float x,
			float y,
			uint32 button
		) {
			var ev = new Event();
			ev.local_valid = true;
			ev.local_type = type;
			ev.local_x = x;
			ev.local_y = y;
			ev.local_button = button;
			return ev;
		}

		public EventType @type()
		{
			if (this.local_valid) {
				return this.local_type;
			}
			var response = GnomeShellRpc.call_value(
				"Clutter-Event.type", this);
			return (EventType) response.retval.get_int();
		}

		public void get_coords(out float x, out float y)
		{
			if (this.local_valid) {
				x = this.local_x;
				y = this.local_y;
				return;
			}
			var response = GnomeShellRpc.call_value(
				"Clutter-Event.get_coords", this);
			x = (float) response.args.get(0).get_float();
			y = (float) response.args.get(1).get_float();
		}

		public uint32 get_button()
		{
			if (this.local_valid) {
				return this.local_button;
			}
			var response = GnomeShellRpc.call_value(
				"Clutter-Event.get_button", this);
			return (uint32) response.retval.get_uint();
		}
