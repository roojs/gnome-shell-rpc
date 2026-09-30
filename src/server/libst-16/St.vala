/**
 * Ffi arms for St types with no C {@code *_new} (Widget, DrawingArea,
 * Viewport). {@link OLLMrpc.Gi} would parent-walk those to
 * {@code clutter_actor_new}; this mints via {@code g_object_new} instead.
 *
 * Wire method is {@code new}; Vala ctor symbol would collide — class ctor
 * cname is {@code _create}, mint exports as {@code _new} for Ffi.
 *
 * @see docs/bugs/done/2026-09-07-st-ctor-parent-walks-to-actor.md
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class St : GLib.Object
	{
		public static void rpc_register()
		{
			var helper = new St();
			OLLMrpc.Request.add_class("St-Widget", typeof(St), "new", "", null);
			OLLMrpc.Request.register_live("St-Widget", helper);
			OLLMrpc.Request.add_class("St-DrawingArea", typeof(St), "new", "", null);
			OLLMrpc.Request.register_live("St-DrawingArea", helper);
			OLLMrpc.Request.add_class("St-Viewport", typeof(St), "new", "", null);
			OLLMrpc.Request.register_live("St-Viewport", helper);
		}

		[CCode (cname = "gnome_shell_rpc_rpc_helper_st_create")]
		public St()
		{
		}

		/**
		 * ''St-*.new'' — {@code g_object_new} of the glib type for the wire
		 * prefix. GJS {@code St.Widget} subclasses mint
		 * {@code Helper-Actor.create} from the client Actor parent-walk.
		 *
		 * @param request inbound construct (no lease)
		 */
		[CCode (cname = "gnome_shell_rpc_rpc_helper_st_new")]
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
			request.reply(new OLLMrpc.Response() {
				retval = OLLMrpc.val("o", created),
			});
		}
	}
}
