/**
 * Delivers {@link Meta.BackgroundActor} construct RPC.
 *
 * Lease id in {@link OLLMrpc.Response.args} (same packing as
 * {@link Background.create}) — avoid {@code retval} re-entering client
 * {@code construct}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class BackgroundActor : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-BackgroundActor", typeof(BackgroundActor),
				"create", "ti",
				null
			);
			OLLMrpc.Request.register_live("Helper-BackgroundActor",
				new BackgroundActor());
		}

		/**
		 * ''Helper-BackgroundActor.create'' — compositor background actor.
		 *
		 * @param request inbound RPC
		 * @param display_lease lease id of {@link Meta.Display}
		 * @param monitor monitor index
		 */
		public void create(
			OLLMrpc.Request request,
			uint64 display_lease,
			int monitor
		) {
			var actor = new Meta.BackgroundActor(
				(Meta.Display) request.connection.leases.get((int) display_lease),
				monitor
			);
			/* Stock attach MetaBackgroundContent — client facade needs its
			 * lease so content.background / set_vignette RPC to the peer. */
			var content = actor.get_content();
			uint64 content_handle = 0;
			if (content != null) {
				content_handle = (uint64) request.connection.export(content);
			}
			/* Shell wallpaper lives under window_group; drop Plugin's
			 * opaque pre-RPC fill so it no longer covers this actor. */
			GnomeShellRpc.Plugin.release_placeholder_backgrounds();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args( "tt", (uint64) request.connection.export(actor),
					content_handle),
			});
		}
	}
}
