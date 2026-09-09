		/**
		 * Client-owned themes keyed by ThemeContext lease.
		 *
		 * {@code get_for_stage} re-decodes a live handle into a **new** proxy
		 * each time ({@code parse_object} does not reuse {@code proxies}), so
		 * a per-instance field would reset to null after {@code loadTheme()}.
		 */
		private static Gee.HashMap<int, Theme>? themes_by_lid;

		public static ThemeContext get_for_stage(Clutter.Stage stage)
		{
			var response = GnomeShellRpc.call_value(
				"St-ThemeContext.get_for_stage", null,
				OLLMrpc.args("o", stage));
			return (ThemeContext) response.retval.get_object();
		}

		/**
		 * Client-owned {@link Theme} for {@code loadTheme()} — not on RPC wire.
		 */
		public Theme? get_theme()
		{
			if (this.rpc_lid == 0 || themes_by_lid == null) {
				return null;
			}
			return themes_by_lid.get((int) this.rpc_lid);
		}

		public void set_theme(Theme theme)
		{
			if (this.rpc_lid == 0) {
				GLib.warning("St.ThemeContext.set_theme: no rpc_lid");
				return;
			}
			if (themes_by_lid == null) {
				themes_by_lid = new Gee.HashMap<int, Theme>();
			}
			themes_by_lid.set((int) this.rpc_lid, theme);
			string application_uri;
			string theme_uri;
			string default_uri;
			theme.construct_uris(
				out application_uri, out theme_uri, out default_uri);
			GnomeShellRpc.call_value(
				"Helper-ThemeContext.set_theme",
				this,
				OLLMrpc.args(
					"sssas",
					application_uri,
					theme_uri,
					default_uri,
					theme.stylesheet_uris()));
			this.changed();
		}
