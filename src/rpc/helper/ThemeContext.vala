/**
 * Delivers theme apply for the leased {@code StThemeContext}.
 *
 * Client {@code St.Theme} is local (Gio.File not on wire). Wire sends
 * stylesheet URIs; compositor builds a real StTheme via libst C and
 * applies it so server-side St chrome can paint CSS.
 *
 * Wire prefix ''Helper-ThemeContext''.
 *
 * ℹ️ Why {@code [CCode]} {@code st_theme_*} and not {@code new St.Theme}:
 * mutter-rpc already links distro {@code libst-16.so} (for
 * {@code Gi.register("St")}), and distro ships {@code St-16.gir} /
 * typelib, but **no** installable {@code St-16.vapi}. Vala therefore
 * cannot {@code --pkg} stock St on the server. Our
 * {@code st-rpc-16.vapi} is the **client** RPC relay — wrong stack here.
 * Keep these externs (or a future server-only VAPI we own); do not pull
 * st-rpc into mutter-rpc for Theme.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class ThemeContext : GLib.Object
	{
		private static bool theme_gresource_tried = false;

		/* Distro libst C — see file comment (no St.vapi on server). */
		[CCode (cname = "st_theme_new")]
		private static extern GLib.Object st_theme_new(
			GLib.File? application_stylesheet,
			GLib.File? theme_stylesheet,
			GLib.File? default_stylesheet
		);

		[CCode (cname = "st_theme_load_stylesheet")]
		private static extern bool st_theme_load_stylesheet(
			GLib.Object theme,
			GLib.File file
		) throws GLib.Error;

		[CCode (cname = "st_theme_context_set_theme")]
		private static extern void st_theme_context_set_theme(
			GLib.Object context,
			GLib.Object? theme
		);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-ThemeContext", typeof(ThemeContext),
				"set_theme", "sssas",
				null
			);
			OLLMrpc.Request.register_live(
				"Helper-ThemeContext", new ThemeContext());
		}

		/**
		 * ''Helper-ThemeContext.set_theme'' — URI list → real StTheme on
		 * the leased StThemeContext.
		 *
		 * @param request inbound RPC (lease = ThemeContext)
		 * @param application_uri author stylesheet, or empty
		 * @param theme_uri user stylesheet, or empty
		 * @param default_uri UA stylesheet, or empty
		 * @param custom_uris extra stylesheets (extensions)
		 */
		public void set_theme(
			OLLMrpc.Request request,
			string application_uri,
			string theme_uri,
			string default_uri,
			string[] custom_uris
		) {
			if (!theme_gresource_tried) {
				theme_gresource_tried = true;
				var gresource_path = "/usr/share/gnome-shell/gnome-shell-theme.gresource";
				try {
					var resource = GLib.Resource.load(gresource_path);
					GLib.resources_register(resource);
				} catch (GLib.Error e) {
					GLib.warning("Helper-ThemeContext: register %s: %s",
						gresource_path, e.message);
				}
			}
			var ctx = (GLib.Object) request.connection.leases.get(
				(int) request.lease_id);
			var application = this.file_for_stylesheet_uri(application_uri);
			var theme_file = this.file_for_stylesheet_uri(theme_uri);
			var default_file = this.file_for_stylesheet_uri(default_uri);
			if (default_file == null && application == null && theme_file == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.INVALID_ARGUMENT(
						"Helper-ThemeContext.set_theme: no stylesheet uris"));
				return;
			}
			var theme = st_theme_new(application, theme_file, default_file);
			foreach (var uri in custom_uris) {
				var custom = this.file_for_stylesheet_uri(uri);
				if (custom == null) {
					continue;
				}
				try {
					st_theme_load_stylesheet(theme, custom);
				} catch (GLib.Error e) {
					GLib.warning("Helper-ThemeContext.load_stylesheet %s: %s",
						uri, e.message);
				}
			}
			st_theme_context_set_theme(ctx, theme);
			GLib.message("Helper-ThemeContext.set_theme ok default=%s app=%s customs=%d",
				default_uri, application_uri, custom_uris.length);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * Resolve a client stylesheet URI for the compositor process.
		 *
		 * {@code resource:///org/gnome/shell/theme/…} needs the theme
		 * gresource registered in {@link set_theme}; also try the on-disk
		 * theme dir when the resource is missing.
		 */
		private GLib.File? file_for_stylesheet_uri(string uri)
		{
			if (uri == null || uri == "") {
				return null;
			}
			var file = GLib.File.new_for_uri(uri);
			if (file.query_exists()) {
				return file;
			}
			const string RESOURCE_PREFIX = "resource:///org/gnome/shell/theme/";
			if (uri.has_prefix(RESOURCE_PREFIX)) {
				var name = uri.substring(RESOURCE_PREFIX.length);
				var path = GLib.Path.build_filename(
					"/usr/share/gnome-shell/theme", name);
				var disk = GLib.File.new_for_path(path);
				if (disk.query_exists()) {
					return disk;
				}
			}
			GLib.warning("Helper-ThemeContext: stylesheet missing uri=%s", uri);
			return null;
		}
	}
}
