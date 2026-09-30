/**
 * Delivers {@code GLib.Icon} for leased {@code StIcon} — icons are not
 * marshallable as objects on the RPC wire, so the client sends
 * {@code g_icon_to_string} form and the compositor rebuilds via
 * {@code g_icon_new_for_string}.
 *
 * Wire prefix {@code Helper-Icon}. Same St.vapi constraint as
 * {@link ThemeContext}: distro has no installable St-16.vapi for mutter-rpc.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Icon : GLib.Object
	{
		[CCode (cname = "st_icon_set_gicon")]
		private static extern void st_icon_set_gicon(
			GLib.Object icon,
			GLib.Icon? gicon
		);

		[CCode (cname = "st_icon_get_gicon")]
		private static extern unowned GLib.Icon? st_icon_get_gicon(
			GLib.Object icon
		);

		[CCode (cname = "st_icon_set_fallback_gicon")]
		private static extern void st_icon_set_fallback_gicon(
			GLib.Object icon,
			GLib.Icon? gicon
		);

		[CCode (cname = "st_icon_get_fallback_gicon")]
		private static extern unowned GLib.Icon? st_icon_get_fallback_gicon(
			GLib.Object icon
		);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Icon", typeof(Icon),
				"set_gicon", "s",
				"get_gicon", "",
				"set_fallback_gicon", "s",
				"get_fallback_gicon", "",
				null
			);
			OLLMrpc.Request.register_live("Helper-Icon", new Icon());
		}

		/**
		 * {@code Helper-Icon.set_gicon} — serialized icon → real GIcon on
		 * the leased StIcon.
		 */
		public void set_gicon(OLLMrpc.Request request, string icon_str)
		{
			var icon = (GLib.Object) request.connection.leases.get(
				(int) request.lease_id);
			GLib.Icon? gicon = null;
			if (icon_str != null && icon_str.length > 0) {
				try {
					gicon = GLib.Icon.new_for_string(icon_str);
				} catch (GLib.Error e) {
					GLib.warning("Helper-Icon.set_gicon(%s): %s",
						icon_str, e.message);
				}
			}
			st_icon_set_gicon(icon, gicon);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * {@code Helper-Icon.get_gicon} — GIcon → serialized string.
		 */
		public void get_gicon(OLLMrpc.Request request)
		{
			var icon = (GLib.Object) request.connection.leases.get(
				(int) request.lease_id);
			var gicon = st_icon_get_gicon(icon);
			string wire = "";
			if (gicon != null) {
				string? s = gicon.to_string();
				if (s != null) {
					wire = s;
				}
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("s", wire),
			});
		}

		/**
		 * {@code Helper-Icon.set_fallback_gicon}.
		 */
		public void set_fallback_gicon(
			OLLMrpc.Request request,
			string icon_str
		) {
			var icon = (GLib.Object) request.connection.leases.get(
				(int) request.lease_id);
			GLib.Icon? gicon = null;
			if (icon_str != null && icon_str.length > 0) {
				try {
					gicon = GLib.Icon.new_for_string(icon_str);
				} catch (GLib.Error e) {
					GLib.warning("Helper-Icon.set_fallback_gicon(%s): %s",
						icon_str, e.message);
				}
			}
			st_icon_set_fallback_gicon(icon, gicon);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * {@code Helper-Icon.get_fallback_gicon}.
		 */
		public void get_fallback_gicon(OLLMrpc.Request request)
		{
			var icon = (GLib.Object) request.connection.leases.get(
				(int) request.lease_id);
			var gicon = st_icon_get_fallback_gicon(icon);
			string wire = "";
			if (gicon != null) {
				string? s = gicon.to_string();
				if (s != null) {
					wire = s;
				}
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("s", wire),
			});
		}
	}
}
