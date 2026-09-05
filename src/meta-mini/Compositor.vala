// FIXME: 0.5.3 POC — hand stub until generator wires get_window_actors.
namespace Meta
{
	public class Compositor : GLib.Object, OLLMrpc.Live.Handle
	{
		public uint64 rpc_lid { get; set construct; default = 0; }

		public static void register()
		{
			OLLMrpc.Bin.register("Meta-Compositor", typeof(Compositor));
		}

		public GLib.List<WindowActor> get_window_actors()
		{
			var response = GnomeShellRpc.call_value("Meta-Compositor.get_window_actors", this);
			var list = new GLib.List<WindowActor>();
			for (var i = 0; i < response.args.size; i++) {
				var actor = new WindowActor();
				actor.rpc_lid = response.args.get(i).get_uint64();
				list.append(actor);
			}
			return list;
		}

		public Backend get_backend()
		{
			var response = GnomeShellRpc.call_value(
				"Meta-Compositor.get_backend", this);
			var backend = new Backend();
			backend.rpc_lid = response.args.get(0).get_uint64();
			return backend;
		}

		public void disable_unredirect()
		{
			GnomeShellRpc.call_value(
				"Meta-Compositor.disable_unredirect", this);
		}

		public void enable_unredirect()
		{
			GnomeShellRpc.call_value(
				"Meta-Compositor.enable_unredirect", this);
		}
	}
}
