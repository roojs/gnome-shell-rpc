// FIXME: 0.5.3 POC — hand stub until generator wires get_window_actors.
namespace Meta
{
	public class Compositor : GLib.Object
	{
		public static void register()
		{
			OLLMrpc.Bin.register("Meta-Compositor", typeof(Compositor));
		}

		public GLib.List<WindowActor> get_window_actors()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values("Meta-Compositor.get_window_actors", this);
			var list = new GLib.List<WindowActor>();
			for (var i = 0; i < response.args.size; i++) {
				var actor = new WindowActor();
				actor.set_data(
					"gsr-lease-id",
					response.args.get(i).get_uint64().to_string()
				);
				list.append(actor);
			}
			return list;
		}

		public Backend get_backend()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Compositor.get_backend", this);
			var backend = new Backend();
			backend.set_data(
				"gsr-lease-id",
				response.args.get(0).get_uint64().to_string()
			);
			return backend;
		}
	}
}
