/**
 * Server-side paired {@link GLib.Cancellable} for Override RPC (plan 0.5.7).
 *
 * Wire prefix {@code Server-Cancellable}. Twins are created on first
 * {@link lookup} and cancelled via {@link cancel}.
 */
namespace Gsr.Server
{
	public class Cancellable : GLib.Object
	{
		private static Gee.HashMap<int, GLib.Cancellable>? twins = null;

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Server-Cancellable", typeof(Cancellable),
				"cancel", "t",
				null
			);
			OLLMrpc.Request.register("Server-Cancellable", new Cancellable());
		}

		public static GLib.Cancellable? lookup(uint64 id)
		{
			if (id == 0) {
				return null;
			}
			if (Cancellable.twins == null) {
				Cancellable.twins = new Gee.HashMap<int, GLib.Cancellable>();
			}
			var key = (int) id;
			if (!Cancellable.twins.has_key(key)) {
				Cancellable.twins.set(key, new GLib.Cancellable());
			}
			return Cancellable.twins.get(key);
		}

		public void cancel(OLLMrpc.Request request, uint64 id)
		{
			if (id == 0 || Cancellable.twins == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var key = (int) id;
			if (Cancellable.twins.has_key(key)) {
				Cancellable.twins.get(key).cancel();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
