/**
 * Consumer {@code RPC-Live-Callback} — same as stock, plus error replies.
 *
 * Stock {@link OLLMrpc.Live.Callback.reply} only copies success args into
 * {@link OLLMrpc.Live.Hook.reply_args}. Preferred fallthrough needs the
 * existing throw path: client sends {@code reply_id} + error code → we
 * store {@link OLLMrpc.Error} on the Hook and {@link reply_error} so
 * {@code Client.call} throws (same as any other RPC failure).
 *
 * Replaces the stock live singleton after {@link OLLMrpc.rpc_register}.
 */
namespace GnomeShellRpc.Rpc
{
	public class LiveCallback : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"RPC-Live-Callback", typeof(LiveCallback),
				"register", "",
				"unregister", "t",
				"reply", "",
				null);
			OLLMrpc.Request.register_live(
				"RPC-Live-Callback", new LiveCallback());
		}

		public void register(OLLMrpc.Request request)
		{
			if (!request.connection.live_handles) {
				GLib.error("Callback.register requires live_handles");
			}
			var id = request.connection.next_handle;
			request.connection.next_handle++;
			request.connection.callbacks.set(id, new OLLMrpc.Live.Hook() {
				connection = request.connection,
				id = id
			});
			request.reply(new OLLMrpc.Response() {
				args = OLLMrpc.args("t", (uint64) id),
			});
		}

		public void unregister(OLLMrpc.Request request, uint64 callback_id)
		{
			if (!request.connection.live_handles) {
				GLib.error("Callback.unregister requires live_handles");
			}
			var id = (int) callback_id;
			if (!request.connection.callbacks.has_key(id)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			request.connection.callbacks.get(id).replied = true;
			request.connection.callbacks.unset(id);
			request.reply(new OLLMrpc.Response());
		}

		/**
		 * Complete one Hook wait. Success: args after {@code reply_id} →
		 * {@code reply_args}. Error: one INT ({@link OLLMrpc.RpcErrorCode})
		 * → Hook gets {@link OLLMrpc.Error}, client {@link reply_error}.
		 */
		public void reply(OLLMrpc.Request request)
		{
			if (!request.connection.live_handles) {
				GLib.error("Callback.reply requires live_handles");
			}
			if (request.args.size == 0) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var correlation = (int) request.args.get(0).get_uint64();
			foreach (var id in request.connection.callbacks.keys) {
				var row = request.connection.callbacks.get(id);
				if (row.reply_id != correlation) {
					continue;
				}
				row.reply_args.clear();
				if (request.args.size == 2
						&& request.args.get(1).type() == GLib.Type.INT) {
					var code = request.args.get(1).get_int();
					var err = new OLLMrpc.Error(code, "live callback error");
					var val = GLib.Value(typeof(OLLMrpc.Error));
					val.set_object(err);
					row.reply_args.add(val);
					row.replied = true;
					request.connection.reply_error(request, code);
					return;
				}
				for (var i = 1; i < request.args.size; i++) {
					row.reply_args.add(request.args.get(i));
				}
				row.replied = true;
				request.reply(new OLLMrpc.Response());
				return;
			}
			request.connection.reply_error(request,
				(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
		}
	}
}
