/**
 * Compositor {@code st_theme_node_new}.
 *
 * Wire prefix {@code Gsr-St-ThemeNode}. Distro has no St-16.vapi for
 * mutter-rpc — same CCode pattern as {@link ThemeContext}.
 *
 * The element type crosses as a type name. {@code void} and an empty
 * name are {@link GLib.Type.NONE}, which matches the stage selector.
 * A theme flag uses the theme already on the context. The client
 * {@code St.Theme} is local files, not a compositor object.
 */
namespace Gsr.Server.St
{
	public class ThemeNode : GLib.Object
	{
		[CCode (cname = "st_theme_node_new")]
		private static extern GLib.Object? st_theme_node_new(
			GLib.Object context,
			GLib.Object? parent_node,
			GLib.Object? theme,
			GLib.Type element_type,
			string? element_id,
			string? element_class,
			string? pseudo_class,
			string? inline_style
		);

		[CCode (cname = "st_theme_context_get_theme")]
		private static extern GLib.Object? st_theme_context_get_theme(
			GLib.Object context
		);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-St-ThemeNode", typeof(ThemeNode),
				"create", "oobsssss",
				null
			);
			OLLMrpc.Request.register_live(
				"Gsr-St-ThemeNode", new ThemeNode());
		}

		/**
		 * {@code Gsr-St-ThemeNode.create} — stock
		 * {@code st_theme_node_new}. The lease id is in
		 * {@link OLLMrpc.Response.args}, so the client constructor can
		 * set {@code rpc_lid} without constructing a second node.
		 */
		public void create(
			OLLMrpc.Request request,
			GLib.Object context,
			GLib.Object? parent_node,
			bool has_theme,
			string type_name,
			string element_id,
			string element_class,
			string pseudo_class,
			string inline_style
		) {
			if (context == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			GLib.Type element_type;
			if (type_name == "" || type_name == "void") {
				element_type = GLib.Type.NONE;
			} else {
				element_type = GLib.Type.from_name(type_name);
				if (element_type == GLib.Type.INVALID) {
					request.connection.reply_error(request,
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
					return;
				}
			}
			GLib.Object? theme = null;
			if (has_theme) {
				theme = st_theme_context_get_theme(context);
			}
			var node = st_theme_node_new(
				context,
				parent_node,
				theme,
				element_type,
				element_id == "" ? null : element_id,
				element_class == "" ? null : element_class,
				pseudo_class == "" ? null : pseudo_class,
				inline_style == "" ? null : inline_style
			);
			if (node == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(node)),
			});
		}
	}
}
