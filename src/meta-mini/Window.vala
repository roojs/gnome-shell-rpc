namespace Meta
{
	/**
	 * Client stub for one leased compositor window.
	 *
	 * Callers assign {@link title} / {@link wm_class}, then
	 * {@code set_data("gsr-lease-id", …)} for the plugin handle.
	 * Mutators use typelib FFI ({@code Meta-Window.*} + lease_id).
	 *
	 * == Example ==
	 *
	 * {{{
	 * var win = new Meta.Window() {
	 *     title = snap.title,
	 *     wm_class = snap.wm_class,
	 * };
	 * win.set_data("gsr-lease-id", snap.id.to_string());
	 * win.minimize();
	 * win.unminimize();
	 * }}}
	 */
	public class Window : GLib.Object
	{
		public string title { get; set; default = ""; }
		public string wm_class { get; set; default = ""; }

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
	}

	/**
	 * Watch func for {@link Window.foreach_transient} (mutter Vala drops
	 * GIR user_data).
	 */
	public delegate bool WindowForeachFunc(Window window);
}
