	private Clutter.Event? drag_event_cache;
	private Clutter.Event? begin_event_cache;

	/**
	 * Stock {@code manual-mode}. GJS sets this in the {@code new}
	 * hash before a lease exists, so the value is stashed and sent
	 * with {@code Gsr-St-DndStartGesture.create}.
	 */
	public bool manual_mode {
		[CCode (cname = "st_dnd_start_gesture_get_manual_mode")]
		get {
			if (this.rpc_lid == 0) {
				var stashed = this.rpc_ctor_get("manual-mode");
				if (stashed != null) {
					return stashed.get_boolean();
				}
				return false;
			}
			var response = Gsr.Client.Rpc.call_value(
				"St-DndStartGesture.get_manual_mode", this);
			return (bool) response.retval.get_boolean();
		}
		[CCode (cname = "st_dnd_start_gesture_set_manual_mode")]
		set {
			if (this.rpc_lid == 0) {
				var stored = GLib.Value(typeof(bool));
				stored.set_boolean(value);
				this.rpc_ctor_stash("manual-mode", stored);
				return;
			}
			Gsr.Client.Rpc.call_value(
				"St-DndStartGesture.set_manual_mode", this,
				OLLMrpc.args("b", value));
		}
	}

	/**
	 * Stock {@code timeout-threshold}, milliseconds. Stashed the same
	 * way as {@link manual_mode} when the gesture is not leased yet.
	 */
	public uint32 timeout_threshold {
		[CCode (cname = "st_dnd_start_gesture_get_timeout_threshold")]
		get {
			if (this.rpc_lid == 0) {
				var stashed = this.rpc_ctor_get("timeout-threshold");
				if (stashed != null) {
					return (uint32) stashed.get_uint();
				}
				return 0;
			}
			var response = Gsr.Client.Rpc.call_value(
				"St-DndStartGesture.get_timeout_threshold", this);
			return (uint32) response.retval.get_uint();
		}
		[CCode (cname = "st_dnd_start_gesture_set_timeout_threshold")]
		set {
			if (this.rpc_lid == 0) {
				var stored = GLib.Value(typeof(uint));
				stored.set_uint(value);
				this.rpc_ctor_stash("timeout-threshold", stored);
				return;
			}
			Gsr.Client.Rpc.call_value(
				"St-DndStartGesture.set_timeout_threshold", this,
				OLLMrpc.args("u", (uint) value));
		}
	}

	/**
	 * Shell 50 {@code new St.DndStartGesture({ ... })}. There is no GIR
	 * constructor, so this mints the stock gesture after the hash has
	 * been stashed.
	 */
	construct {
		if (this.rpc_lid != 0) {
			this.rpc_ctor_clear();
			return;
		}
		var manual = false;
		var stashed_manual = this.rpc_ctor_get("manual-mode");
		if (stashed_manual != null) {
			manual = stashed_manual.get_boolean();
		}
		var timeout = (uint) 0;
		var stashed_timeout = this.rpc_ctor_get("timeout-threshold");
		if (stashed_timeout != null) {
			timeout = stashed_timeout.get_uint();
		}
		try {
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-DndStartGesture.create", null,
				OLLMrpc.args("bu", manual, timeout));
			this.rpc_lid = response.args.get(0).get_uint64();
			Gsr.Client.Rpc.register_handle(this);
		} catch (GLib.Error e) {
			GLib.warning("%s", e.message);
			this.rpc_ctor_clear();
			return;
		}
		this.rpc_ctor_clear();
	}

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
