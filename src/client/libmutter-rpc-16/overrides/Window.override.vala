		/**
		 * Stock returns the compositor's window actor. Leasing that
		 * actor and cloning it killed the nested display. This stand-in
		 * is one actor per window, with {@code meta_window} set, and
		 * the picture is painted into it. The live window actor stays
		 * on the stage.
		 */
		private WindowActor? compositor_peek;

		public GLib.Object? get_compositor_private()
		{
			if (this.compositor_peek != null) {
				return this.compositor_peek;
			}
			var peek = new WindowActor();
			peek.bound_meta_window = this;
			this.compositor_peek = peek;
			Gsr.Client.Rpc.ensure_signal_subscribe(this, "size-changed");
			this.signal_size_changed.connect(() => {
				Gsr.Client.Rpc.call_value(
					"Gsr-Mutter-Window.preview_actor", this,
					OLLMrpc.args("o", peek));
			});
			Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Window.preview_actor", this,
				OLLMrpc.args("o", peek));
			return peek;
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
