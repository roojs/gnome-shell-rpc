/**
 * Delivers {@link Meta.BackgroundActor} construct RPC.
 *
 * Lease id in {@link OLLMrpc.Response.args} (same packing as
 * {@link Background.create}) — avoid {@code result} re-entering client
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
			var display = (Meta.Display) request.connection.leases.get(
				(int) display_lease
			);
			var actor = new Meta.BackgroundActor(display, monitor);
			var handle = (uint64) request.connection.export(actor);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}
	}
}
