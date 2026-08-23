namespace Meta
{
	/**
	 * Client stub for {@code MetaLaunchContext} (extends {@link Gio.AppLaunchContext}).
	 *
	 * Mirrors mutter: copy {@code DISPLAY} / {@code WAYLAND_DISPLAY} from the
	 * process environment into the launch context. Also clears
	 * {@code WAYLAND_SOCKET} so Gio-spawned children use the display name
	 * (this process may be a {@code Meta.WaylandClient} child with a private fd).
	 */
	public class LaunchContext : GLib.AppLaunchContext
	{
		construct
		{
			var x11_display = GLib.Environment.get_variable("DISPLAY");
			var wayland_display = GLib.Environment.get_variable("WAYLAND_DISPLAY");
			if (x11_display != null && x11_display.length > 0) {
				this.setenv("DISPLAY", x11_display);
			}
			if (wayland_display != null && wayland_display.length > 0) {
				this.setenv("WAYLAND_DISPLAY", wayland_display);
			}
			this.unsetenv("WAYLAND_SOCKET");
		}

		/**
		 * Stock {@code meta_launch_context_set_timestamp} (no-op until needed).
		 */
		public void set_timestamp(uint32 timestamp)
		{
		}
	}
}
