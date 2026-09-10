/**
 * Concrete {@link Clutter.Constraint} base for JS subclasses, plus Ffi
 * {@code Clutter-AlignConstraint.new} / Bind / Snap (real mutter types).
 *
 * Hierarchy (no type switch in {@code create}):
 * - {@code Helper-Constraint.create} → this class + client {@code update_allocation}
 * - {@code Clutter-AlignConstraint.new} etc. → {@code g_object_new} of that type
 *
 * Leaf {@code *.new} cannot use stock GObject ctor symbols on Ffi — same
 * cname pattern as {@link St}.
 *
 * @see docs/bugs/2026-09-07-align-constraint-relay-mint.md
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Constraint : Clutter.Constraint
	{
		public OLLMrpc.Live.Hook update_hook;

		public static void rpc_register()
		{
			var helper = new Constraint();
			OLLMrpc.Request.add_class(
				"Helper-Constraint", typeof(Constraint),
				"create", "t",
				"set_update_callback", "t",
				null
			);
			OLLMrpc.Request.register_live("Helper-Constraint", helper);
			OLLMrpc.Request.add_class("Clutter-AlignConstraint", typeof(Constraint), "new", "", null);
			OLLMrpc.Request.register_live("Clutter-AlignConstraint", helper);
			OLLMrpc.Request.add_class("Clutter-BindConstraint", typeof(Constraint), "new", "", null);
			OLLMrpc.Request.register_live("Clutter-BindConstraint", helper);
			OLLMrpc.Request.add_class("Clutter-SnapConstraint", typeof(Constraint), "new", "", null);
			OLLMrpc.Request.register_live("Clutter-SnapConstraint", helper);
		}

		/* Distinct from mint cname {@code *_new} (Ffi leaf construct). */
		[CCode (cname = "gnome_shell_rpc_rpc_helper_constraint_ctor")]
		public Constraint()
		{
		}

		public override void update_allocation(
			Clutter.Actor actor,
			Clutter.ActorBox allocation
		) {
			if (this.update_hook == null) {
				return;
			}
			GLib.message(
				"DBG Helper.Constraint.update_allocation emit BEGIN hook_id=%d",
				this.update_hook.id);
			this.update_hook.emit(OLLMrpc.args("tdddd",
				this.update_hook.connection.export(actor),
				(double) allocation.x1, (double) allocation.y1,
				(double) allocation.x2, (double) allocation.y2));
			GLib.message(
				"DBG Helper.Constraint.update_allocation emit END hook_id=%d reply_id=%d replied=%s",
				this.update_hook.id,
				this.update_hook.reply_id,
				this.update_hook.replied.to_string());
			if (this.update_hook.reply_args.size < 4) {
				return;
			}
			allocation.x1 = (float) this.update_hook.reply_args.get(0).get_double();
			allocation.y1 = (float) this.update_hook.reply_args.get(1).get_double();
			allocation.x2 = (float) this.update_hook.reply_args.get(2).get_double();
			allocation.y2 = (float) this.update_hook.reply_args.get(3).get_double();
		}

		/**
		 * ''Helper-Constraint.create'' — JS / abstract Constraint peer.
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
			var created = new Constraint();
			created.update_hook = request.connection.callbacks.get(
				(int) callback_id);
			var handle = (uint64) request.connection.export(created);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		/**
		 * ''Clutter-AlignConstraint.new'' / Bind / Snap — real mutter GType.
		 *
		 * @param request inbound construct (no lease)
		 */
		[CCode (cname = "gnome_shell_rpc_rpc_helper_constraint_new")]
		public void mint(OLLMrpc.Request request)
		{
			var dot = request.method.index_of_char('.');
			if (dot < 1 || request.method.substring(dot + 1) != "new") {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.METHOD_NOT_FOUND);
				return;
			}
			var glib_name = request.method.substring(0, dot).replace("-", "");
			var gtype = GLib.Type.from_name(glib_name);
			if (gtype == GLib.Type.INVALID) {
				GLib.critical("Helper.Constraint: GType %s not registered",
					glib_name);
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
			var created = GLib.Object.new(gtype);
			var handle = (uint64) request.connection.export(created);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		/**
		 * Attach {@code update_allocation} hook on an existing base lease.
		 *
		 * @param request lease is a {@link Constraint}
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
			var base_constraint = request.connection.leases.get(id) as Constraint;
			if (base_constraint == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					error = new OLLMrpc.Error(
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
						"lease is not Helper.Constraint"
					),
				});
				return;
			}
			base_constraint.update_hook =
				request.connection.callbacks.get((int) callback_id);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
