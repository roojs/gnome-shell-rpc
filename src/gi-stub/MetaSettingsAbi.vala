namespace GnomeShellRpc.GiStub
{
	/**
	 * Client bridge for {@code meta_settings_get_ui_scaling_factor} (libshell C).
	 * Compositor scale via {@code Helper-Settings}; local settings stub stays
	 * in {@code c-meta-shell-gaps.c} for {@code meta_backend_get_settings}.
	 */
	[CCode (cname = "meta_settings_get_ui_scaling_factor")]
	public static int meta_settings_get_ui_scaling_factor(
		[CCode (type = "MetaSettings*")] void* settings
	) {
		try {
			var response = Runtime.call_values(
				"Helper-Settings.get_ui_scaling_factor", null);
			return response.args.get(0).get_int();
		} catch (GLib.Error e) {
			GLib.warning(
				"meta_settings_get_ui_scaling_factor: %s", e.message);
			return 1;
		}
	}
}
