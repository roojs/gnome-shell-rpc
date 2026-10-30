	construct {
		if (this.rpc_lid != 0) {
			return;
		}
		Gsr.Client.Rpc.hook_rows = new Gee.ArrayList<Gsr.Client.Rpc.InvokeRow>();
		string[] always = {};
		var overridden = Gsr.Client.Rpc.VfuncRelay.overridden(this.get_type(), "Clutter",
			"GestureAction", typeof(GestureAction).name(), always);

		var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
		foreach (var name in overridden) {
			var vfunc_id = -1;
			var hook_id = this.bind_vfunc(name, out vfunc_id);
			if (hook_id == 0) {
				continue;
			}
			vfunc_ids.add("i", vfunc_id);
		}
		var response = Gsr.Client.Rpc.call_value("Gsr-Clutter-GestureAction.create");
		this.rpc_lid = response.args.get(0).get_uint64();
		Gsr.Client.Rpc.register_handle(this);
		if (Gsr.Client.Rpc.hook_rows.size == 0) {
			Gsr.Client.Rpc.hook_rows = null;
			return;
		}
		var hooks = Gsr.Client.Rpc.call_value("Gsr-Clutter-GestureAction.add_hooks",
			this, OLLMrpc.args("v", vfunc_ids.end()));

		var ids = hooks.args.get(0).get_variant();
		if (Gsr.Client.Rpc.handlers == null) {
			Gsr.Client.Rpc.handlers = new Gee.HashMap<int, Gsr.Client.Rpc.InvokeRow>();
		}
		var n = (int) ids.n_children();
		for (var i = 0; i < n; i++) {
			var id = ids.get_child_value(i).get_uint64();
			Gsr.Client.Rpc.handlers.set((int) id, Gsr.Client.Rpc.hook_rows.get(i));
		}
		Gsr.Client.Rpc.hook_rows = null;
	}

		/**
		 * ActorMeta {@code enabled} — parent is size-locked C GType (no Vala
		 * props). GJS {@code TouchSwipeGesture} / SwipeTracker
		 * {@code bind_property('enabled', …)}.
		 */
		public bool enabled { get; set construct; default = true; }

		private Event? last_event_cache;

		/**
		 * Stock {@code clutter_gesture_action_get_last_event}. Compact
		 * {@link Event}; swipeTracker only reads {@code get_time()}.
		 */
		public unowned Event? get_last_event(uint point)
		{
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Clutter-GestureAction.get_last_event", this,
				OLLMrpc.args("u", point));
			if (response.args.size < 5) {
				return null;
			}
			this.last_event_cache = event_from_values(response.args);
			return this.last_event_cache;
		}
