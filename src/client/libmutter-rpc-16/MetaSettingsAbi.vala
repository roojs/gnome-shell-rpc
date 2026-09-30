namespace GnomeShellRpc.GiStub
{
	/**
	 * Vala bridge to {@code meta_backend_get_settings} in {@code c-meta-shell-gaps.c}.
	 * {@code meta_settings_get_ui_scaling_factor} C export: {@code Meta.Settings}.
	 */
	[CCode (cname = "gsr_meta_backend_get_settings_vala")]
	private extern void* meta_backend_get_settings_ptr(
		[CCode (type = "MetaBackend*")] Meta.Backend backend
	);

	public static GLib.Object meta_backend_get_settings(Meta.Backend backend)
	{
		return (GLib.Object) meta_backend_get_settings_ptr(backend);
	}
}
