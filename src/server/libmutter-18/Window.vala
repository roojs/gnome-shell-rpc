/**
 * Delivers {@link global::Meta.Window} Override RPC (plan 0.5.6 B3).
 *
 * Wire prefix ''Gsr-Mutter-Window''. Lease is the window.
 * {@link global::Meta.WindowForeachFunc} continue is the bool on
 * {@link OLLMrpc.Live.Hook.reply_args} after {@code RPC-Live-Callback.reply}.
 * {@code begin_grab_op} takes a {@link global::Clutter.Sprite}.
 * The 18 startup calls {@link rpc_register}. The 16 build does not.
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
				"begin_grab_op", "oubff",
				"get_compositor_private", "",
				null
			);
			OLLMrpc.Request.register_live("Gsr-Mutter-Window", new Window());
		}

		/**
		 * ''Gsr-Mutter-Window.get_compositor_private'' — lease of the
		 * live {@link global::Meta.WindowActor}. Same object
		 * {@link Gsr.Server.Meta.Compositor.get_window_actors} exports.
		 */
		public void get_compositor_private(OLLMrpc.Request request)
		{
			var window = (global::Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			var priv = window.get_compositor_private()
				as global::Meta.WindowActor;
			uint64 lid = 0;
			if (priv != null) {
				lid = request.connection.export(priv);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", lid),
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

		/**
		 * ''Gsr-Mutter-Window.begin_grab_op'' — stock
		 * {@code meta_window_begin_grab_op} with the leased sprite.
		 *
		 * @param request inbound RPC; lease is the window
		 * @param op {@link global::Meta.GrabOp}
		 * @param sprite leased {@link global::Clutter.Sprite}, or null
		 * @param timestamp event time
		 * @param has_pos when true, {@code pos_x} and {@code pos_y} are set
		 * @param pos_x hint X
		 * @param pos_y hint Y
		 */
		public void begin_grab_op(
			OLLMrpc.Request request,
			uint op,
			global::Clutter.Sprite? sprite,
			uint timestamp,
			bool has_pos,
			float pos_x,
			float pos_y
		) {
			var window = (global::Meta.Window) request.connection.leases.get(
				(int) request.lease_id);
			Graphene.Point? pos_hint = null;
			if (has_pos) {
				Graphene.Point pos = {};
				pos.x = pos_x;
				pos.y = pos_y;
				pos_hint = pos;
			}
			var ok = window.begin_grab_op((global::Meta.GrabOp) op, sprite,
				timestamp, pos_hint);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
			});
		}
	}
}
