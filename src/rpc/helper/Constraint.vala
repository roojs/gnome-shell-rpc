/**
 * Server→client {@link Clutter.Constraint} vfunc relay (JS subclasses).
 *
 * Wire prefix {@code Helper-Constraint}. {@link create} mints a
 * {@link ConstraintRelay} whose {@code update_allocation} {@link OLLMrpc.Live.Hook.emit}s
 * to the client; reply floats rewrite the actor box.
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

		public override void update_allocation(Clutter.Actor actor, Clutter.ActorBox allocation)
		{
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

	public class Constraint : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Constraint", typeof(Constraint),
				"create", "t",
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
	}
}
