/**
 * Delivers {@code St.IconTheme.get_icon_sizes} — zero-terminated {@code int*}
 * from stock libst, packed as a raw int32 slab ({@link GLib.Bytes} / {@code ay}).
 *
 * Wire prefix {@code Helper-IconTheme}. Distro has no St-16.vapi for
 * mutter-rpc — same CCode pattern as {@link ThemeContext}.
 *
 * Prefer Bytes over Variant {@code ai}: StreamValue's Variant numeric-array
 * path double-unrefs under Vala ownership.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class IconTheme : GLib.Object
	{
		[CCode (cname = "st_icon_theme_get_icon_sizes")]
		private static extern int* st_icon_theme_get_icon_sizes(
			GLib.Object icon_theme,
			string icon_name
		);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-IconTheme", typeof(IconTheme),
				"get_icon_sizes", "s",
				null
			);
			OLLMrpc.Request.register_live(
				"Helper-IconTheme", new IconTheme());
		}

		/**
		 * {@code Helper-IconTheme.get_icon_sizes} — stock sizes → Bytes slab.
		 *
		 * @param request inbound RPC (lease = IconTheme)
		 * @param icon_name icon name to look up
		 */
		public void get_icon_sizes(OLLMrpc.Request request, string icon_name)
		{
			var theme = (GLib.Object) request.connection.leases.get(
				(int) request.lease_id);
			var ptr = st_icon_theme_get_icon_sizes(theme, icon_name);
			int[] sizes = {};
			if (ptr != null) {
				for (var i = 0; ptr[i] != 0; i++) {
					sizes += ptr[i];
				}
				GLib.free(ptr);
			}
			var nbytes = sizes.length * (int) sizeof(int);
			var buf = new uint8[nbytes];
			if (nbytes > 0) {
				GLib.Memory.copy(buf, sizes, nbytes);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("ay", new GLib.Bytes(buf)),
			});
		}
	}
}
