/**
 * Helper-Interval — mint stock Interval from a type-name indicator
 * (no GType int on the wire). See docs/bugs/done/2026-09-16-interval-value-type-mint.md.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Interval : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class("Helper-Interval", typeof(Interval),
				"create", "s", null);
			OLLMrpc.Request.register_live("Helper-Interval", new Interval());
		}

		/**
		 * ''Helper-Interval.create'' — {@code name} is {@link GLib.Type.name}
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
			var peer = (Clutter.Interval) GLib.Object.new(
				typeof(Clutter.Interval), "value-type", gtype);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t",
					(uint64) request.connection.export(peer)),
			});
		}
	}
}
