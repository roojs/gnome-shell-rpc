namespace Gsr.Client.Clutter
{
	public class Batch
	{
		public static void flush_prop(GLib.Object? instance) throws GLib.Error
		{
			var actor = instance as global::Clutter.Actor;
			if (actor != null && actor.prop_batch_open && actor.prop_batch.size == 0) {
				actor.prop_batch_open = false;
			}
			if (actor != null && actor.prop_batch.size > 0) {
				actor.prop_batch_open = false;
				var send = new Gee.ArrayList<GLib.Value?>();
				foreach (var entry in actor.prop_batch.entries) {
					var key = GLib.Value(typeof(string));
					key.set_string(entry.key);
					send.add(key);
					send.add(entry.value);
				}
				actor.prop_batch.clear();
				Gsr.Client.Rpc.call_value("Gsr-Clutter-Actor.add_properties", actor, send);
			}
		}

		public static OLLMrpc.Response call_value(
			string method,
			global::Clutter.Actor actor,
			string name,
			Gee.ArrayList<GLib.Value?>? args = null,
			OLLMrpc.Live.Buffer? buffer = null
		) throws GLib.Error {
			if (actor.prop_batch_open && args != null && args.size > 0) {
				actor.prop_batch.set(name, args.get(args.size - 1));
				return new OLLMrpc.Response();
			}
			return Gsr.Client.Rpc.call_value(method, actor, args, buffer);
		}
	}
}
