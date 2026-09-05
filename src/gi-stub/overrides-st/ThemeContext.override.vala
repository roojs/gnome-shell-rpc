		private Theme? active_theme;

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
			return this.active_theme;
		}

		public void set_theme(Theme theme)
		{
			this.active_theme = theme;
		}
