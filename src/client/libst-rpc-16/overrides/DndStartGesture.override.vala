	private Clutter.Event? drag_event_cache;
	private Clutter.Event? begin_event_cache;

	/**
	 * Stock {@code st_dnd_start_gesture_get_drag_triggering_event}.
	 * The compositor packs the compact event; this rebuilds it.
	 */
	public unowned Clutter.Event? get_drag_triggering_event()
	{
		var response = Gsr.Client.Rpc.call_value(
			"Gsr-St-DndStartGesture.get_drag_triggering_event", this);
		this.drag_event_cache = Clutter.event_from_values(response.args);
		return this.drag_event_cache;
	}

	/**
	 * Stock {@code st_dnd_start_gesture_get_point_begin_event}.
	 * The compositor packs the compact event; this rebuilds it.
	 */
	public unowned Clutter.Event? get_point_begin_event()
	{
		var response = Gsr.Client.Rpc.call_value(
			"Gsr-St-DndStartGesture.get_point_begin_event", this);
		this.begin_event_cache = Clutter.event_from_values(response.args);
		return this.begin_event_cache;
	}
