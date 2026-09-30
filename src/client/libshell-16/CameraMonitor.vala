/**
 * Owned {@code Shell.CameraMonitor} — stock {@code shell-camera-monitor}
 * surface used by quick-settings camera privacy indicator.
 *
 * GIR: constructible GObject + {@code cameras-in-use}. PipeWire registry
 * watch (stock {@code HAVE_PIPEWIRE}) deferred — property stays false so
 * the indicator stays hidden until the real monitor is ported.
 */
namespace Shell
{
	public class CameraMonitor : GLib.Object
	{
		public bool cameras_in_use { get; private set; default = false; }
	}
}
