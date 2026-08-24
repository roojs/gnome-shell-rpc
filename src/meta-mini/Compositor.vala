// FIXME: 0.5.3 POC — hand stub until generator wires get_window_actors.
namespace Meta
{
	public class Compositor : GLib.Object
	{
		public GLib.List<WindowActor> get_window_actors()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values("Meta-Compositor.get_window_actors", this);
			var list = new GLib.List<WindowActor>();
			for (var i = 0; i < response.result.size; i++) {
				list.append((WindowActor) response.result.get(i));
			}
			return list;
		}
	}
}
