		public void foreach_transient(WindowForeachFunc func)
		{
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				var win = (Window) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				return OLLMrpc.args("b", func(win));
			});
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Window.foreach_transient", this,
				OLLMrpc.args("t", callback_id));
		}

		public void foreach_ancestor(WindowForeachFunc func)
		{
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				var win = (Window) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				return OLLMrpc.args("b", func(win));
			});
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Window.foreach_ancestor", this,
				OLLMrpc.args("t", callback_id));
		}

		public bool begin_grab_op(
			GrabOp op,
			Clutter.InputDevice? device,
			Clutter.EventSequence? sequence,
			uint32 timestamp,
			Graphene.Point? pos_hint
		) {
			uint64 device_lease = 0;
			var device_name = "";
			if (device != null) {
				var lease = (uint64) device.get_data<void*>("rpc-lid");
				if (lease != 0) {
					device_lease = lease;
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
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Window.begin_grab_op", this,
				OLLMrpc.args("utsiubff", (uint) op, device_lease, device_name,
					sequence_slot, timestamp, has_pos, pos_x, pos_y));
			return response.retval.get_boolean();
		}
