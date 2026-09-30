	/**
	 * Event is Compact — not on the wire. Stock looks up key-focus for
	 * key/IM events, otherwise the actor under the event coords
	 * ({@link get_actor_at_pos} REACTIVE) at call time.
	 */
	[CCode (cname = "clutter_stage_get_event_actor")]
	public Actor? get_event_actor(Event event)
	{
		var type = event.type();
		if (type == EventType.key_press
				|| type == EventType.key_release
				|| type == EventType.im_commit
				|| type == EventType.im_delete
				|| type == EventType.im_preedit) {
			return this.key_focus;
		}
		float x = 0.0f, y = 0.0f;
		event.get_coords(out x, out y);
		return this.get_actor_at_pos(PickMode.reactive, x, y);
	}
