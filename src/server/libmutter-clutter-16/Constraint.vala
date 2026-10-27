/**
 * Concrete {@link global::Clutter.Constraint} base for JS subclasses, plus Ffi
 * {@code Clutter-AlignConstraint.new} / Bind / Snap (real mutter types).
 *
 * Hierarchy (no type switch in {@code create}):
 * - {@code Gsr-Clutter-Constraint.create} → this class + client {@code update_allocation}
 * - {@code Clutter-AlignConstraint.new} etc. → {@code g_object_new} of that type
 *
 * Leaf {@code *.new} cannot use stock GObject ctor symbols on Ffi — same
 * cname pattern as {@link St}.
 *
 * @see docs/bugs/2026-09-07-align-constraint-relay-mint.md
 */
namespace Gsr.Server.Clutter
{
	public class Constraint : global::Clutter.Constraint
	{
		public OLLMrpc.Live.Hook update_hook;

		/**
		 * {@code Clutter.BindConstraint} is sealed, so the class vfunc
		 * is replaced by ''gsr_bind_constraint_install'' in
		 * bind-constraint-place.c. That calls the stock allocation,
		 * then {@link gsr_bind_constraint_place}.
		 */
		[CCode (cname = "gsr_bind_constraint_install")]
		private static extern void gsr_bind_constraint_install();

		/**
		 * Mutter's vapi returns a {@link global::Clutter.Vertex}. The
		 * mutter 16 function writes a {@link Graphene.Point3D}.
		 *
		 * @param self the source actor
		 * @param ancestor the constrained actor's parent
		 * @param point source-local point, origin for this correction
		 * @param vertex that point in {@code ancestor}'s coordinates
		 */
		[CCode (cname = "clutter_actor_apply_relative_transform_to_point")]
		private static extern void apply_relative_transform_to_point(
			global::Clutter.Actor self,
			global::Clutter.Actor ancestor,
			[CCode (type = "const graphene_point3d_t*")]
			ref Graphene.Point3D point,
			out Graphene.Point3D vertex
		);

		/**
		 * Move a position bind onto the source's stored parent position
		 * when {@code get_x} or {@code get_y} is 0.
		 *
		 * The stock vfunc has already written {@code allocation}.
		 * Width, height, and size binds stay as that vfunc wrote them.
		 * {@code allocation} is the same {@link global::Clutter.ActorBox}
		 * the class vfunc received.
		 *
		 * @param bind the sealed mutter constraint
		 * @param actor the actor being allocated
		 * @param allocation box written by the stock vfunc
		 */
		[CCode (cname = "gsr_bind_constraint_place")]
		public static void gsr_bind_constraint_place(
			global::Clutter.BindConstraint bind,
			global::Clutter.Actor actor,
			ref global::Clutter.ActorBox allocation
		) {
			unowned global::Clutter.Actor source = bind.get_source();
			if (source == null) {
				return;
			}
			var coordinate = bind.get_coordinate();
			if (coordinate != global::Clutter.BindCoordinate.X &&
				coordinate != global::Clutter.BindCoordinate.Y &&
				coordinate != global::Clutter.BindCoordinate.POSITION &&
				coordinate != global::Clutter.BindCoordinate.ALL) 
			{
				return;
			}
			var x = source.get_x();
			var y = source.get_y();
			if (x != 0f && y != 0f) {
				return;
			}
			var parent = actor.get_parent();
			if (parent == null) {
				return;
			}
			var point = Graphene.Point3D();
			point.init(0f, 0f, 0f);
			Graphene.Point3D vertex;
			Constraint.apply_relative_transform_to_point(source, parent, ref point, out vertex);
			if (x == 0f &&
				(coordinate == global::Clutter.BindCoordinate.X ||
				coordinate == global::Clutter.BindCoordinate.POSITION ||
				coordinate == global::Clutter.BindCoordinate.ALL)) 
			{
				allocation.x1 += vertex.x;
				allocation.x2 += vertex.x;
			}
			if (y == 0f &&
				(coordinate == global::Clutter.BindCoordinate.Y ||
				coordinate == global::Clutter.BindCoordinate.POSITION ||
				coordinate == global::Clutter.BindCoordinate.ALL)) 
			{
				allocation.y1 += vertex.y;
				allocation.y2 += vertex.y;
			}
			global::Clutter.ActorBox.clamp_to_pixel(ref allocation);
		}

		public static void rpc_register()
		{
			Constraint.gsr_bind_constraint_install();
			var helper = new Constraint();
			OLLMrpc.Request.add_class(
				"Gsr-Clutter-Constraint", typeof(Constraint),
				"create", "t",
				"set_update_callback", "t",
				null
			);
			OLLMrpc.Request.register_live("Gsr-Clutter-Constraint", helper);
			OLLMrpc.Request.add_class("Clutter-AlignConstraint", typeof(Constraint), "new", "", null);
			OLLMrpc.Request.register_live("Clutter-AlignConstraint", helper);
			OLLMrpc.Request.add_class("Clutter-BindConstraint", typeof(Constraint), "new", "", null);
			OLLMrpc.Request.register_live("Clutter-BindConstraint", helper);
			OLLMrpc.Request.add_class("Clutter-SnapConstraint", typeof(Constraint), "new", "", null);
			OLLMrpc.Request.register_live("Clutter-SnapConstraint", helper);
		}

		/* Ffi looks up {@code gsr_server_clutter_constraint_new}. Keep the
		 * Vala ctor off that symbol so {@link mint} can own it. */
		[CCode (cname = "gnome_shell_rpc_rpc_helper_constraint_ctor")]
		public Constraint()
		{
		}

		public override void update_allocation(
			global::Clutter.Actor actor,
			global::Clutter.ActorBox allocation
		) {
			if (this.update_hook == null) {
				return;
			}
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

		/**
		 * ''Gsr-Clutter-Constraint.create'' — JS / abstract Constraint peer.
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
		[CCode (cname = "gsr_server_clutter_constraint_new")]
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
