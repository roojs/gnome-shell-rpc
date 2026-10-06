/**
 * Client rebuild of a {@link Meta.BarrierEvent}.
 *
 * Field order matches {@link Gsr.Server.Meta.BarrierEventOverride}:
 * event id, dt, time, x, y, dx, dy, released, grabbed.
 */
namespace Shell
{
	internal class BarrierEventOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(Meta.BarrierEvent); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			unowned var ev = (Meta.BarrierEvent*) src.get_boxed();
			return OLLMrpc.args("iiuddddbb", ev.event_id, ev.dt, ev.time,
				ev.x, ev.y, ev.dx, ev.dy, ev.released, ev.grabbed);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 9;
			var ev = (Meta.BarrierEvent*) GLib.malloc0(sizeof(Meta.BarrierEvent));
			ev.event_id = fields.get(index).get_int();
			ev.dt = fields.get(index + 1).get_int();
			ev.time = fields.get(index + 2).get_uint();
			ev.x = fields.get(index + 3).get_double();
			ev.y = fields.get(index + 4).get_double();
			ev.dx = fields.get(index + 5).get_double();
			ev.dy = fields.get(index + 6).get_double();
			ev.released = fields.get(index + 7).get_boolean();
			ev.grabbed = fields.get(index + 8).get_boolean();
			var v = GLib.Value(typeof(Meta.BarrierEvent));
			v.take_boxed(ev);
			return v;
		}

		internal static void register()
		{
			OLLMrpc.Bin.TypeOverride.register(new BarrierEventOverride());
		}
	}
}
