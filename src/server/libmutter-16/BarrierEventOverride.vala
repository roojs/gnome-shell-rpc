/**
 * {@link global::Meta.BarrierEvent} as event id, dt, time, x, y, dx, dy,
 * released, grabbed.
 *
 * {@code Meta.Barrier.hit} and {@code left} otherwise write the raw box
 * and {@code StreamValue} resets the connection.
 */
namespace Gsr.Server.Meta
{
	public class BarrierEventOverride : OLLMrpc.Bin.TypeOverride
	{
		public override GLib.Type override_type {
			get { return typeof(global::Meta.BarrierEvent); }
		}

		public override Gee.ArrayList<GLib.Value?> pack(GLib.Value src)
		{
			if (src.get_boxed() == null) {
				return OLLMrpc.args("iiuddddbb", 0, 0, (uint) 0,
					0.0, 0.0, 0.0, 0.0, false, false);
			}
			unowned var ev = (global::Meta.BarrierEvent) src.get_boxed();
			return OLLMrpc.args("iiuddddbb", ev.event_id, ev.dt, ev.time,
				ev.x, ev.y, ev.dx, ev.dy, ev.released, ev.grabbed);
		}

		public override GLib.Value unpack(
			Gee.ArrayList<GLib.Value?> fields,
			int index,
			out int consumed
		) {
			consumed = 9;
			return GLib.Value(typeof(global::Meta.BarrierEvent));
		}
	}
}
