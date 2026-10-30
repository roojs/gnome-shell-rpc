/**
 * Stock {@code st_spinner_content_new}. The compositor owns the
 * spinner. It animates once {@link Clutter.Actor.set_content}
 * attaches it to a mapped actor.
 *
 * Wire prefix {@code Gsr-St-SpinnerContent}.
 */
namespace Gsr.Server.St
{
	public class SpinnerContent : GLib.Object
	{
		[CCode (cname = "st_spinner_content_new")]
		private static extern GLib.Object st_spinner_content_new();

		[CCode (cname = "clutter_content_get_preferred_size")]
		private static extern bool clutter_content_get_preferred_size(
			[CCode (type = "ClutterContent*")] void* content,
			out float width,
			out float height
		);

		[CCode (cname = "clutter_content_invalidate")]
		private static extern void clutter_content_invalidate(
			[CCode (type = "ClutterContent*")] void* content
		);

		[CCode (cname = "clutter_content_invalidate_size")]
		private static extern void clutter_content_invalidate_size(
			[CCode (type = "ClutterContent*")] void* content
		);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-St-SpinnerContent", typeof(SpinnerContent),
				"create", "",
				"get_preferred_size", "",
				"invalidate", "",
				"invalidate_size", "",
				null
			);
			OLLMrpc.Request.register_live(
				"Gsr-St-SpinnerContent", new SpinnerContent());
		}

		/**
		 * {@code Gsr-St-SpinnerContent.create} — stock
		 * {@code st_spinner_content_new}.
		 */
		public void create(OLLMrpc.Request request)
		{
			var peer = st_spinner_content_new();
			request.connection.export(peer);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", peer),
			});
		}

		/**
		 * {@code clutter_content_get_preferred_size} on the leased spinner.
		 */
		public void get_preferred_size(OLLMrpc.Request request)
		{
			var content = request.connection.leases.get((int) request.lease_id);
			if (content == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			float width = 0;
			float height = 0;
			var ok = clutter_content_get_preferred_size(content, out width, out height);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", ok),
				args = OLLMrpc.args("dd", (double) width, (double) height),
			});
		}

		/**
		 * {@code clutter_content_invalidate} on the leased spinner.
		 */
		public void invalidate(OLLMrpc.Request request)
		{
			var content = request.connection.leases.get((int) request.lease_id);
			if (content == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			clutter_content_invalidate(content);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * {@code clutter_content_invalidate_size} on the leased spinner.
		 */
		public void invalidate_size(OLLMrpc.Request request)
		{
			var content = request.connection.leases.get((int) request.lease_id);
			if (content == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			clutter_content_invalidate_size(content);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
