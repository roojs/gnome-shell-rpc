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
			var current_time_val = GLib.Value(GLib.Type.UINT);
			current_time_val.set_uint(current_time);
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Window.activate",
				this,
				{ current_time_val }
			);
		}

		/**
		 * Request close (WM delete) for this window.
		 *
		 * @param timestamp event timestamp ({@code 0} is fine on nested Wayland)
		 */
		public void delete(uint32 timestamp = 0)
		{
			var timestamp_val = GLib.Value(GLib.Type.UINT);
			timestamp_val.set_uint(timestamp);
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Window.delete",
				this,
				{ timestamp_val }
			);
		}
	}
}
