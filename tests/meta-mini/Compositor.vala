// FIXME: 0.5.3 POC — hand stub until generator wires get_window_actors.
namespace Meta
{
	public class Compositor : GLib.Object, OLLMrpc.Live.Interface
	{
		public uint64 rpc_lid { get; set construct; default = 0; }

		public static void register()
		{
			OLLMrpc.Bin.register("Meta-Compositor", typeof(Compositor));
		}

		public GLib.List<WindowActor> get_window_actors()
		{
			var response = Gsr.Client.Rpc.call_value("Meta-Compositor.get_window_actors", this);
			var list = new GLib.List<WindowActor>();
			for (var i = 0; i < response.args.size; i++) {
				var val = response.args.get(i);
				if (!val.type().is_a(typeof(GLib.Object))) {
					continue;
				}
				var actor = val.get_object() as WindowActor;
				if (actor == null) {
					continue;
				}
				list.append(actor);
			}
			return list;
		}

		public Backend get_backend()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Meta-Compositor.get_backend", this);
			var backend = new Backend();
			backend.rpc_lid = response.args.get(0).get_uint64();
			return backend;
		}

		public void disable_unredirect()
		{
			Gsr.Client.Rpc.call_value(
				"Meta-Compositor.disable_unredirect", this);
		}

		public void enable_unredirect()
		{
			Gsr.Client.Rpc.call_value(
				"Meta-Compositor.enable_unredirect", this);
		}
	}
}
