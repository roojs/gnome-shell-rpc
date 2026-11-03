/**
 * Server peer for {@code Shell.EdgeDragGesture}.
 *
 * The stock class is a {@code Clutter.Gesture}. {@code add_action} needs a
 * lease of a real gesture. Recognition is still the stock C behaviour; this
 * peer only exists so the shell can attach the action.
 */
namespace Gsr.Server.Shell
{
	private class EdgeDrag : global::Clutter.Gesture
	{
	}

	public class EdgeDragGesture : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register_alias("Clutter-Gesture", typeof(EdgeDrag));
			OLLMrpc.Request.add_class(
				"Gsr-Shell-EdgeDragGesture", typeof(EdgeDragGesture),
				"create", "",
				null
			);
			OLLMrpc.Request.register_live("Gsr-Shell-EdgeDragGesture", new EdgeDragGesture());
		}

		public void create(OLLMrpc.Request request)
		{
			var created = new EdgeDrag();
			var handle = (uint64) request.connection.export(created);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}
	}
}
