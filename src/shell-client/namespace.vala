namespace GnomeShellRpc.ShellClient
{
	[CCode (cname = "gnome_shell_rpc_shell_bootstrap_connected", cheader_filename = "bootstrap.h")]
	public extern void shell_bootstrap_connected();

	[CCode (cname = "gnome_shell_rpc_get_gjs_context", cheader_filename = "bootstrap.h")]
	public extern Gjs.Context get_gjs_context();
}
