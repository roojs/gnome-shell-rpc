/**
 * Delivers {@code meta_settings_get_ui_scaling_factor} for libshell (0.7.1 Phase 2).
 *
 * Wire prefix ''Gsr-Mutter-Settings''. No lease — reads compositor backend settings.
 */
namespace Gsr.Server.Meta
{
	public class Settings : GLib.Object
	{
		public global::Meta.Display meta_display { get; construct; }

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Mutter-Settings", typeof(Settings),
				"get_ui_scaling_factor", "",
				null
			);
		}

		/**
		 * Bind compositor display and register the live singleton.
		 *
		 * @param display mutter display (server process)
		 */
		public static void bind(global::Meta.Display display)
		{
			OLLMrpc.Request.register_live(
				"Gsr-Mutter-Settings",
				new Settings(display)
			);
		}

		public Settings(global::Meta.Display meta_display)
		{
			GLib.Object(meta_display: meta_display);
		}

		/**
		 * ''Gsr-Mutter-Settings.get_ui_scaling_factor'' — compositor UI scale.
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
				retval = OLLMrpc.val("i", scale),
			});
		}
	}
}
