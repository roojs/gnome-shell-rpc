/**
 * Delivers {@link global::Meta.Window} Override RPC (plan 0.5.6 B3).
 *
 * Wire prefix ''Gsr-Mutter-Window'', plus
 * ''Meta-Window.get_compositor_private''. Lease is the window.
 * {@link global::Meta.WindowForeachFunc} continue is the bool on
 * {@link OLLMrpc.Live.Hook.reply_args} after {@code RPC-Live-Callback.reply}.
 */
namespace Gsr.Server.Meta
{
	public class Window : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Mutter-Window", typeof(Window),
				"foreach_transient", "t",
				"foreach_ancestor", "t",
				"begin_grab_op", "uosiubff",
				null
			);
			OLLMrpc.Request.register_live("Gsr-Mutter-Window",
				 new Window());
			OLLMrpc.Request.add_class(
				"Meta-Window", typeof(Window),
				"get_compositor_private", "",
				null
			);
			OLLMrpc.Request.register_live("Meta-Window", new Window());
		}

		/**
		 * ''Meta-Window.get_compositor_private'' — compositor wrapper for
		 * the leased window.
		 *
		 * Stock returns the window actor. The overview clones that actor
		 * for the workspace thumbnail. A null wrapper replies with no
		 * return value.
		 *
		 * @param request inbound RPC; {@code lease_id} is the window
		 */
		public void get_compositor_private(OLLMrpc.Request request)
		{
			var window = (global::Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			var priv = window.get_compositor_private();
			if (priv == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var wire = priv.get_type();
			while (wire != GLib.Type.INVALID && wire != typeof(GLib.Object)
					&& (OLLMrpc.Bin.gtype_to_alias == null
						|| !OLLMrpc.Bin.gtype_to_alias.has_key(wire))) {
				wire = wire.parent();
			}
			if (wire == GLib.Type.INVALID || wire == typeof(GLib.Object)
					|| OLLMrpc.Bin.gtype_to_alias == null
					|| !OLLMrpc.Bin.gtype_to_alias.has_key(wire)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			request.connection.export(priv);
			var packed = GLib.Value(wire);
			packed.set_object(priv);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = packed,
			});
		}

		public void foreach_transient(
			OLLMrpc.Request request,
			uint64 callback_id
		) {
			var window = (global::Meta.Window) request.connection.leases.get(
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
			var window = (global::Meta.Window) request.connection.leases.get(
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
			global::Clutter.InputDevice? device,
			string device_name,
			int sequence_slot,
			uint timestamp,
			bool has_pos,
			float pos_x,
			float pos_y
		) {
			var window = (global::Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			var resolved = Gsr.Server.Clutter.Devices.resolve(device, device_name);
			Graphene.Point? pos_hint = null;
			if (has_pos) {
				Graphene.Point pos = {};
				pos.x = pos_x;
				pos.y = pos_y;
				pos_hint = pos;
			}
			/* EventSequence is process-local; slot alone cannot rebuild it. */
			global::Clutter.EventSequence? sequence = null;
			if (sequence_slot >= 0) {
				GLib.debug(
					"begin_grab_op: sequence slot %d ignored (no cross-process sequence)",
					sequence_slot);
			}
			var ok = window.begin_grab_op((global::Meta.GrabOp) op, resolved, sequence,
				timestamp, pos_hint);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
			});
		}
	}
}
