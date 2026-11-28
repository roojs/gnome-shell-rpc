/**
 * Ffi arms for St types with no C {@code *_new} (Widget, DrawingArea,
 * Viewport). {@link OLLMrpc.Gi} would parent-walk those to
 * {@code clutter_actor_new}; this mints via {@code g_object_new} instead.
 *
 * Wire method is {@code new}. Ffi looks up {@code gsr_server_st_st_new}.
 * The Vala ctor uses a different cname so {@link mint} can own that symbol.
 *
 * @see docs/bugs/done/2026-09-07-st-ctor-parent-walks-to-actor.md
 */
namespace Gsr.Server.St
{
	public class St : GLib.Object
	{
		/**
		 * Startup overview paint hold for actors this helper mints.
		 */
		private OverviewPaintHold paint_hold;

		public static void rpc_register()
		{
			var helper = new St(new OverviewPaintHold());
			OLLMrpc.Request.add_class("St-Widget", typeof(St),
				"new", "",
				"set_label_actor", "o",
				null);
			OLLMrpc.Request.register_live("St-Widget", helper);
			OLLMrpc.Request.add_class("St-DrawingArea", typeof(St), "new", "");
			OLLMrpc.Request.register_live("St-DrawingArea", helper);
			OLLMrpc.Request.add_class("St-Viewport", typeof(St), "new", "");
			OLLMrpc.Request.register_live("St-Viewport", helper);
		}

		[CCode (cname = "gnome_shell_rpc_rpc_helper_st_create")]
		public St(OverviewPaintHold paint_hold)
		{
			this.paint_hold = paint_hold;
		}

		/**
		 * ''St-*.new'' — {@code g_object_new} of the glib type for the wire
		 * prefix. GJS {@code global::St.Widget} subclasses mint
		 * {@code Gsr-Clutter-Actor.create} from the client Actor parent-walk.
		 *
		 * @param request inbound construct (no lease)
		 */
		/**
		 * ''St-Widget.set_label_actor'' — GObject {@code label-actor} on the
		 * leased widget. Batched setters use {@code add_properties}; hover
		 * paths call this directly when the batch is closed.
		 */
		public void set_label_actor(OLLMrpc.Request request, uint64 label_lease)
		{
			var widget = request.connection.leases.get(
				(int) request.lease_id) as global::St.Widget;
			if (widget == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			global::Clutter.Actor? label = null;
			if (label_lease != 0) {
				label = request.connection.leases.get(
					(int) label_lease) as global::Clutter.Actor;
				if (label == null) {
					request.connection.reply_error(request,
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
					return;
				}
			}
			var pspec = widget.get_class().find_property("label-actor");
			if (pspec == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var obj_value = GLib.Value(pspec.value_type);
			obj_value.set_object(label);
			widget.set_property("label-actor", obj_value);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		[CCode (cname = "gsr_server_st_st_new")]
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
				GLib.critical("Helper.St: GType %s not registered", glib_name);
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
			var created = GLib.Object.new(gtype);
			request.connection.export(created);
			var actor = created as global::Clutter.Actor;
			if (actor != null) {
				this.paint_hold.watch(
					actor,
					(Gsr.Server.Rpc.Connection) request.connection);
			}
			request.reply(new OLLMrpc.Response() {
				retval = OLLMrpc.val("o", created),
			});
		}
	}
}
