/**
 * Helper-Text — {@code Clutter.Text.get_layout} snapshot.
 *
 * {@code Pango.Layout} is not a wire type. The caller only reads the
 * layout the text already owns, so this returns the fields and the
 * client builds its own {@link Pango.Layout}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Text : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Text", typeof(Text),
				"get_layout", "",
				null
			);
			OLLMrpc.Request.register_live("Helper-Text", new Text());
		}

		/**
		 * ''Helper-Text.get_layout'' — text, font, width, height, wrap,
		 * ellipsize, alignment, indent, spacing, attributes.
		 * Empty args means the server layout is null.
		 */
		public void get_layout(OLLMrpc.Request request)
		{
			var text = (Clutter.Text) request.connection.leases.get(
				(int) request.lease_id);
			var layout = text.get_layout();
			if (layout == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			string font_s = "";
			var font = layout.get_font_description();
			if (font != null) {
				font_s = font.to_string();
			}
			string attrs_s = "";
			var attrs = layout.get_attributes();
			if (attrs != null) {
				attrs_s = attrs.to_string();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args(
					"ssiiiiiiis",
					layout.get_text(),
					font_s,
					layout.get_width(),
					layout.get_height(),
					(int) layout.get_wrap(),
					(int) layout.get_ellipsize(),
					(int) layout.get_alignment(),
					layout.get_indent(),
					layout.get_spacing(),
					attrs_s),
			});
		}
	}
}
