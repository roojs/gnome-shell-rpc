		/**
		 * Stock {@code meta_settings_get_ui_scaling_factor} — compositor scale
		 * via {@code Helper-Settings}; C export for libshell link.
		 */
		public int get_ui_scaling_factor()
		{
			try {
				var response = GnomeShellRpc.call_value(
					"Helper-Settings.get_ui_scaling_factor", null);
				return response.retval.get_int();
			} catch (GLib.Error e) {
				GLib.warning("get_ui_scaling_factor: %s", e.message);
				return 1;
			}
		}
