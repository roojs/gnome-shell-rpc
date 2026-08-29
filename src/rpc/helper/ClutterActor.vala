/**
 * Clutter Actor / Context helpers — uint64 lease in args (not result).
 *
 * Live GObject rows in {@link OLLMrpc.Response.result} arrive with handle 0;
 * same packing as {@link GnomeShellRpc.Ui.Display.get_compositor}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class ClutterActor : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Clutter-Actor", typeof(ClutterActor),
				"get_context", "",
				null
			);
			OLLMrpc.Request.register_live("Clutter-Actor",
				new ClutterActor());
		}

		public void get_context(OLLMrpc.Request request)
		{
			var actor = (global::Clutter.Actor) request.connection.leases.get(
				(int) request.lease_id);
			var ctx = actor.get_context();
			var handle = (uint64) request.connection.export(ctx);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}
	}

	public class ClutterContext : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Clutter-Context", typeof(ClutterContext),
				"get_backend", "",
				null
			);
			OLLMrpc.Request.register_live("Clutter-Context",
				new ClutterContext());
		}

		public void get_backend(OLLMrpc.Request request)
		{
			var ctx = (global::Clutter.Context) request.connection.leases.get(
				(int) request.lease_id);
			var backend = ctx.get_backend();
			var handle = (uint64) request.connection.export(backend);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}
	}
}
