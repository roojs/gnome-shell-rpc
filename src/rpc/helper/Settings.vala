/**
 * Delivers {@code meta_settings_get_ui_scaling_factor} for libshell (0.7.1 Phase 2).
 *
 * Wire prefix ''Helper-Settings''. No lease — reads compositor backend settings.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Settings : GLib.Object
	{
		public Meta.Display meta_display { get; construct; }

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Settings", typeof(Settings),
				"get_ui_scaling_factor", "",
				null
			);
		}

		/**
		 * Bind compositor display and register the live singleton.
		 *
		 * @param display mutter display (server process)
		 */
		public static void bind(Meta.Display display)
		{
			OLLMrpc.Request.register_live(
				"Helper-Settings",
				new Settings(display)
			);
		}

		public Settings(Meta.Display meta_display)
		{
			GLib.Object(meta_display: meta_display);
		}

		/**
		 * ''Helper-Settings.get_ui_scaling_factor'' — compositor UI scale.
		 *
		 * @param request inbound RPC
		 */
		public void get_ui_scaling_factor(OLLMrpc.Request request)
		{
			var scale = this.meta_display
				.get_context()
				.get_backend()
				.get_settings()
				.get_ui_scaling_factor();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("i", scale),
			});
		}
	}
}
