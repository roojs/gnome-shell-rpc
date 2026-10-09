/**
 * Gsr-Clutter-Interval — mint only. set_initial/final use capital-V on stock
 * Clutter-Interval.set_*_value (no kind casting).
 * See docs/bugs/done/2026-09-16-interval-value-type-mint.md.
 */
namespace Gsr.Server.Clutter
{
	public class Interval : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class("Gsr-Clutter-Interval", typeof(Interval),
				"create", "s",
				"set_initial_box", "tay",
				"set_final_box", "tay",
				null);
			OLLMrpc.Request.register_live("Gsr-Clutter-Interval", new Interval());
		}

		/**
		 * ''Gsr-Clutter-Interval.create'' — {@code name} is {@link GLib.Type.name}
		 * from the client; {@link GLib.Type.from_name} is the local resolve.
		 */
		public void create(OLLMrpc.Request request, string name)
		{
			var gtype = GLib.Type.from_name(name);
			if (gtype == GLib.Type.INVALID) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var peer = (global::Clutter.Interval) GLib.Object.new(
				typeof(global::Clutter.Interval), "value-type", gtype);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(peer)),
			});
		}

		/**
		 * ''Gsr-Clutter-Interval.set_initial_box'' — {@code ClutterActorBox}
		 * is not a bin GValue. Bytes are the struct; applied locally.
		 */
		public void set_initial_box(
			OLLMrpc.Request request,
			uint64 lid,
			GLib.Bytes box_bytes
		) {
			this.apply_box(request, lid, box_bytes, true);
		}

		/**
		 * ''Gsr-Clutter-Interval.set_final_box'' — same packing as
		 * {@link set_initial_box}. Workspace layout calls
		 * {@code get_interval().set_final(childBox)}.
		 */
		public void set_final_box(
			OLLMrpc.Request request,
			uint64 lid,
			GLib.Bytes box_bytes
		) {
			this.apply_box(request, lid, box_bytes, false);
		}

		private void apply_box(
			OLLMrpc.Request request,
			uint64 lid,
			GLib.Bytes box_bytes,
			bool is_initial
		) {
			var interval = request.connection.leases.get((int) lid)
				as global::Clutter.Interval;
			if (interval == null
				|| box_bytes.length < sizeof(global::Clutter.ActorBox)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var box = *((global::Clutter.ActorBox*) box_bytes.get_data());
			var v = GLib.Value(typeof(global::Clutter.ActorBox));
			v.set_boxed(&box);
			if (is_initial) {
				interval.set_initial_value(v);
			} else {
				interval.set_final_value(v);
			}
			request.reply(new OLLMrpc.Response());
		}
	}
}
