		/**
		 * Stock {@code meta_window_get_compositor_private}: the live
		 * window actor. Same lease {@code Compositor.get_window_actors}
		 * already exports. Reuse that proxy when the overview has it.
		 */
		public GLib.Object? get_compositor_private()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Window.get_compositor_private", this);
			if (response.args.size < 1) {
				return null;
			}
			var actor_lid = response.args.get(0).get_uint64();
			if (actor_lid == 0) {
				return null;
			}
			if (Gsr.Client.Rpc.client.proxies.has_key((int) actor_lid)) {
				var existing = Gsr.Client.Rpc.client.proxies.get(
					(int) actor_lid) as WindowActor;
				if (existing != null) {
					if (existing.bound_meta_window == null) {
						existing.bound_meta_window = this;
					}
					return existing;
				}
			}
			var actor = new WindowActor();
			actor.rpc_lid = actor_lid;
			actor.bound_meta_window = this;
			Gsr.Client.Rpc.register_handle(actor);
			return actor;
		}

		public void foreach_transient(WindowForeachFunc func)
		{
			var callback_id = Gsr.Client.Rpc.callback_bind((call) => {
				var win = (Window) Gsr.Client.Rpc.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				return OLLMrpc.args("b", func(win));
			});
			Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Window.foreach_transient", this,
				OLLMrpc.args("t", callback_id));
		}

		public void foreach_ancestor(WindowForeachFunc func)
		{
			var callback_id = Gsr.Client.Rpc.callback_bind((call) => {
				var win = (Window) Gsr.Client.Rpc.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				return OLLMrpc.args("b", func(win));
			});
			Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Window.foreach_ancestor", this,
				OLLMrpc.args("t", callback_id));
		}

		public bool begin_grab_op(
			GrabOp op,
			Clutter.InputDevice? device,
			Clutter.EventSequence? sequence,
			uint32 timestamp,
			Graphene.Point? pos_hint
		) {
			Clutter.InputDevice? wire = null;
			var device_name = "";
			if (device != null) {
				if (device.rpc_lid != 0) {
					wire = device;
				} else {
					device_name = device.get_device_name();
				}
			}
			var sequence_slot = -1;
			if (sequence != null) {
				sequence_slot = sequence.get_slot();
			}
			var has_pos = pos_hint != null;
			var pos_x = 0f, pos_y = 0f;
			if (has_pos) {
				pos_x = pos_hint.x;
				pos_y = pos_hint.y;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Window.begin_grab_op", this,
				OLLMrpc.args("uosiubff", (uint) op, wire, device_name,
					sequence_slot, timestamp, has_pos, pos_x, pos_y));
			return response.retval.get_boolean();
		}
