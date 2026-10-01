/**
 * Gsr-Clutter-Interval — mint only. set_initial/final use capital-V on stock
 * Clutter-Interval.set_*_value (no kind casting).
 * See docs/bugs/done/2026-09-16-interval-value-type-mint.md.
 */
namespace Gsr.Server.Clutter
{
	public class Interval : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class("Gsr-Clutter-Interval", typeof(Interval),
				"create", "s",
				null);
			OLLMrpc.Request.register_live("Gsr-Clutter-Interval", new Interval());
		}

		/**
		 * ''Gsr-Clutter-Interval.create'' — {@code name} is {@link GLib.Type.name}
		 * from the client; {@link GLib.Type.from_name} is the local resolve.
		 */
		public void create(OLLMrpc.Request request, string name)
		{
			var gtype = GLib.Type.from_name(name);
			if (gtype == GLib.Type.INVALID) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var peer = (global::Clutter.Interval) GLib.Object.new(
				typeof(global::Clutter.Interval), "value-type", gtype);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(peer)),
			});
		}
	}
}
