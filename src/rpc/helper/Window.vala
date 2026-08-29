/**
 * Delivers {@link Meta.Window} Override RPC (plan 0.5.6 B3).
 *
 * Wire prefix ''Helper-Window''. Lease is the window.
 * {@link Meta.WindowForeachFunc} continue is the bool on
 * {@link OLLMrpc.Live.Hook.reply_args} after {@code RPC-Live-Callback.reply}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Window : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Window", typeof(Window),
				"foreach_transient", "t",
				"foreach_ancestor", "t",
				"begin_grab_op", "utsiubff",
				null
			);
			OLLMrpc.Request.register_live("Helper-Window",
				 new Window());
		}

		public void foreach_transient(
			OLLMrpc.Request request,
			uint64 callback_id
		) {
			var window = (Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				GLib.warning("unknown callback id");
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			window.foreach_transient((w) => {
				row.emit(OLLMrpc.args("t", row.connection.export(w)));
				if (row.reply_args.size < 1) {
					return false;
				}
				return row.reply_args.get(0).get_boolean();
			});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void foreach_ancestor(
			OLLMrpc.Request request,
			uint64 callback_id
		) {
			var window = (Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				GLib.warning("unknown callback id");
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			window.foreach_ancestor((w) => {
				row.emit(OLLMrpc.args("t", row.connection.export(w)));
				if (row.reply_args.size < 1) {
					return false;
				}
				return row.reply_args.get(0).get_boolean();
			});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void begin_grab_op(
			OLLMrpc.Request request,
			uint op,
			uint64 device_lease,
			string device_name,
			int sequence_slot,
			uint timestamp,
			bool has_pos,
			float pos_x,
			float pos_y
		) {
			var window = (Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			var device = Devices.resolve(request.connection, device_lease,
				device_name);
			Graphene.Point? pos_hint = null;
			if (has_pos) {
				Graphene.Point pos = {};
				pos.x = pos_x;
				pos.y = pos_y;
				pos_hint = pos;
			}
			/* EventSequence is process-local; slot alone cannot rebuild it. */
			Clutter.EventSequence? sequence = null;
			if (sequence_slot >= 0) {
				GLib.debug(
					"begin_grab_op: sequence slot %d ignored (no cross-process sequence)",
					sequence_slot);
			}
			var ok = window.begin_grab_op((Meta.GrabOp) op, device, sequence,
				timestamp, pos_hint);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("b", ok),
			});
		}
	}
}
