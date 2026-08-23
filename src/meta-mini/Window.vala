namespace Meta
{
	/**
	 * Client stub for one leased compositor window.
	 *
	 * Callers assign {@link title} / {@link wm_class}, then
	 * {@code set_data("gsr-lease-id", …)} for the plugin handle.
	 * Vala property accessors are the GI {@code get_title} /
	 * {@code get_wm_class} symbols. {@link minimize} sends
	 * {@code Meta-Window.minimize} (typelib FFI on the plugin lease).
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
	 * }}}
	 */
	public class Window : GLib.Object
	{
		public string title { get; set; default = ""; }
		public string wm_class { get; set; default = ""; }

		/**
		 * Minimize this window on the nested compositor.
		 */
		public void minimize()
		{
			var lease = this.get_data<string>("gsr-lease-id");
			if (lease == null || lease.length == 0) {
				GLib.error("Meta.Window.minimize: no gsr-lease-id");
			}
			GnomeShellRpc.GiStub.Runtime.call_void_values(
				"Meta-Window.minimize",
				uint64.parse(lease)
			);
		}
	}
}
