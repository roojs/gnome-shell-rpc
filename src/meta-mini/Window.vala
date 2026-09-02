namespace Meta
{
	/**
	 * Client stub for one leased compositor window.
	 *
	 * Callers assign {@link title} / {@link wm_class}, then
	 * {@link rpc_lid} for the plugin handle.
	 * Mutators use typelib FFI ({@code Meta-Window.*} + lease_id).
	 *
	 * == Example ==
	 *
	 * {{{
	 * var win = new Meta.Window() {
	 *     title = snap.title,
	 *     wm_class = snap.wm_class,
	 * };
	 * win.rpc_lid = snap.id;
	 * win.minimize();
	 * win.unminimize();
	 * }}}
	 */
	public class Window : GLib.Object, OLLMrpc.Live.Handle
	{
		public uint64 rpc_lid { get; set construct; default = 0; }

		public string title { get; set; default = ""; }
		public string wm_class { get; set; default = ""; }

		public static void register()
		{
			OLLMrpc.Bin.register("Meta-Window", typeof(Window));
		}

		/** Minimize this window on the nested compositor. */
		public void minimize()
		{
			GnomeShellRpc.GiStub.Runtime.call_values("Meta-Window.minimize", this);
		}

		/** Unminimize this window on the nested compositor. */
		public void unminimize()
		{
			GnomeShellRpc.GiStub.Runtime.call_values("Meta-Window.unminimize", this);
		}

		/**
		 * Activate (raise/focus) this window.
		 *
		 * @param current_time mutter user-time ({@code 0} is fine on nested Wayland)
		 */
		public void activate(uint32 current_time = 0)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Window.activate",
				this,
				OLLMrpc.args("u", current_time)
			);
		}

		/**
		 * Request close (WM delete) for this window.
		 *
		 * @param timestamp event timestamp ({@code 0} is fine on nested Wayland)
		 */
		public void delete(uint32 timestamp = 0)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Window.delete",
				this,
				OLLMrpc.args("u", timestamp)
			);
		}

		/**
		 * Stock {@code meta_window_foreach_transient}. Client callback
		 * return is the continue bool on {@code RPC-Live-Callback.reply}.
		 */
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

		/**
		 * Stock {@code meta_window_foreach_ancestor}. Same wire as
		 * {@link foreach_transient}.
		 */
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

		/**
		 * Stock {@code meta_window_begin_grab_op}. Device is lease id and/or
		 * name on the wire; Helper resolves on the compositor. EventSequence
		 * is not rebuilt across processes (slot logged server-side only).
		 */
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
				var lease = device.rpc_lid;
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
	}

	/**
	 * Watch func for {@link Window.foreach_transient} (mutter Vala drops
	 * GIR user_data).
	 */
	public delegate bool WindowForeachFunc(Window window);

	public enum GrabOp {
		NONE = 0,
		MOVING = 1,
		KEYBOARD_MOVING = 0x101,
	}
}
