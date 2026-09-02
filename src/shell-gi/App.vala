/**
 * {@code Shell.App} — desktop app wrapper (stock {@code shell-app.c} ActivateAction).
 *
 * {@code environment.js} promisifies {@link activate_action}; body is the real
 * session-bus {@code org.freedesktop.Application.ActivateAction} call.
 */
namespace Shell
{
	public class App : GLib.Object
	{
		public GLib.DesktopAppInfo? app_info { get; construct; default = null; }

		public App(GLib.DesktopAppInfo? app_info = null)
		{
			Object(app_info: app_info);
		}

		public async void activate_action(
			string action_name,
			GLib.Variant? parameter,
			uint timestamp,
			int workspace,
			GLib.Cancellable? cancellable
		) throws GLib.Error
		{
			if (this.app_info == null) {
				throw new GLib.IOError.FAILED(
					"Shell.App.activate_action: no DesktopAppInfo");
			}
			var raw_id = this.app_info.get_id();
			if (raw_id == null || raw_id.length == 0) {
				throw new GLib.IOError.FAILED(
					"Shell.App.activate_action: missing application id");
			}
			var bus_name = raw_id;
			if (raw_id.has_suffix(".desktop")) {
				bus_name = raw_id.slice(0, raw_id.length - ".desktop".length);
			}
			if (!GLib.Application.id_is_valid(bus_name)) {
				throw new GLib.IOError.FAILED(
					"Shell.App.activate_action: invalid application id");
			}
			if (action_name.length == 0) {
				throw new GLib.IOError.INVALID_ARGUMENT(
					"Shell.App.activate_action: empty action_name");
			}

			var param = parameter ?? new GLib.Variant("av", null);
			/* Platform data empty until create_app_launch_context is owned. */
			var platform = new GLib.Variant("a{sv}", null);
			var args = new GLib.Variant("(s@av@a{sv})",
				action_name, param, platform);

			var bus = yield GLib.Bus.@get(GLib.BusType.SESSION, cancellable);
			yield bus.call(
				bus_name,
				"/" + bus_name.replace(".", "/").replace("-", "_"),
				"org.freedesktop.Application",
				"ActivateAction",
				args,
				null,
				GLib.DBusCallFlags.NONE,
				-1,
				cancellable
			);
		}
	}
}
