		/**
		 * Stock {@code meta_settings_get_ui_scaling_factor} — compositor scale
		 * via {@code Gsr-Mutter-Settings}; C export for libshell link.
		 */
		public int get_ui_scaling_factor()
		{
			try {
				var response = Gsr.call_value(
					"Gsr-Mutter-Settings.get_ui_scaling_factor");
				return response.retval.get_int();
			} catch (GLib.Error e) {
				GLib.warning("get_ui_scaling_factor: %s", e.message);
				return 1;
			}
		}
