/**
 * Server→client {@link Clutter.Constraint} vfunc relay (JS subclasses).
 *
 * Peer hierarchy: {@link AlignConstraint} / {@link BindConstraint} /
 * {@link SnapConstraint} extend {@link ConstraintRelay} (wire aliases).
 * Mint stays on {@code Helper-Constraint.create} like other Helpers — Ffi
 * cannot register stock {@code Clutter-*.new} (clashes with GObject
 * {@code *_new}). {@link set_update_callback} attaches the client hook on
 * an existing lease when mint and bind are split.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	/**
	 * Concrete mutter {@link Clutter.Constraint} that Invokes the client
	 * for allocation (abstract {@code Clutter.Constraint} cannot be minted).
	 */
	public class ConstraintRelay : Clutter.Constraint
	{
		public OLLMrpc.Live.Hook update_hook;

		public override void update_allocation(
			Clutter.Actor actor,
			Clutter.ActorBox allocation
		) {
			this.update_hook.emit(OLLMrpc.args("tdddd",
				this.update_hook.connection.export(actor),
				(double) allocation.x1, (double) allocation.y1,
				(double) allocation.x2, (double) allocation.y2));
			if (this.update_hook.reply_args.size < 4) {
				return;
			}
			allocation.x1 = (float) this.update_hook.reply_args.get(0).get_double();
			allocation.y1 = (float) this.update_hook.reply_args.get(1).get_double();
			allocation.x2 = (float) this.update_hook.reply_args.get(2).get_double();
			allocation.y2 = (float) this.update_hook.reply_args.get(3).get_double();
		}
	}

	public class AlignConstraint : ConstraintRelay {}

	public class BindConstraint : ConstraintRelay {}

	public class SnapConstraint : ConstraintRelay {}

	/**
	 * Ffi handler for {@code Helper-Constraint.*} (not a Clutter peer).
	 */
	public class Constraint : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Constraint", typeof(Constraint),
				"create", "t",
				"set_update_callback", "t",
				null
			);
			OLLMrpc.Request.register_live("Helper-Constraint", new Constraint());
		}

		/**
		 * Mint a {@link ConstraintRelay} bound to {@code callback_id}.
		 *
		 * @param request live create
		 * @param callback_id {@code RPC-Live-Callback.register} id
		 */
		public void create(OLLMrpc.Request request, uint64 callback_id)
		{
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					error = new OLLMrpc.Error(
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
						"unknown callback id"
					),
				});
				return;
			}
			var relay = new ConstraintRelay();
			relay.update_hook = request.connection.callbacks.get((int) callback_id);
			var handle = (uint64) request.connection.export(relay);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		/**
		 * Attach {@code update_allocation} hook on an existing relay lease.
		 *
		 * @param request lease is a {@link ConstraintRelay}
		 * @param callback_id {@code RPC-Live-Callback.register} id
		 */
		public void set_update_callback(
			OLLMrpc.Request request,
			uint64 callback_id
		) {
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					error = new OLLMrpc.Error(
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
						"unknown callback id"
					),
				});
				return;
			}
			var id = (int) request.lease_id;
			if (!request.connection.leases.has_key(id)) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					error = new OLLMrpc.Error(
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
						"unknown constraint lease"
					),
				});
				return;
			}
			var relay = request.connection.leases.get(id) as ConstraintRelay;
			if (relay == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					error = new OLLMrpc.Error(
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
						"lease is not ConstraintRelay"
					),
				});
				return;
			}
			relay.update_hook = request.connection.callbacks.get((int) callback_id);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
