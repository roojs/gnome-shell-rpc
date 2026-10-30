/**
 * Delivers {@code st_clipboard_get_text} and {@code st_clipboard_set_content}.
 * The callback and {@link GLib.Bytes} are not Gi wire types.
 *
 * Wire prefix {@code Gsr-St-Clipboard}. Distro has no St-16.vapi — same
 * CCode pattern as {@link ImageContent}.
 */
namespace Gsr.Server.St
{
	public class Clipboard : GLib.Object
	{
		[CCode (instance_pos = 2.9)]
		private delegate void ClipboardTextFunc(GLib.Object clipboard, string? text);

		[CCode (cname = "st_clipboard_get_text")]
		private static extern void st_clipboard_get_text(
			GLib.Object clipboard,
			int type,
			[CCode (scope = "async")]
			ClipboardTextFunc callback
		);

		[CCode (cname = "st_clipboard_set_content")]
		private static extern void st_clipboard_set_content(
			GLib.Object clipboard,
			int type,
			string mimetype,
			GLib.Bytes bytes
		);

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-St-Clipboard", typeof(Clipboard),
				"get_text", "it",
				"set_content", "isx",
				null
			);
			OLLMrpc.Request.register_live(
				"Gsr-St-Clipboard", new Clipboard());
		}

		/**
		 * {@code Gsr-St-Clipboard.get_text}. Stock calls the callback
		 * immediately when the clipboard has no text, and later when the
		 * selection transfer finishes. The reply goes out before a
		 * synchronous callback so the client is not still inside the call.
		 */
		public void get_text(
			OLLMrpc.Request request,
			int type,
			uint64 callback_id
		) {
			var clipboard = (GLib.Object) request.connection.leases.get(
				(int) request.lease_id);
			if (clipboard == null
					|| !request.connection.callbacks.has_key((int) callback_id)) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			var armed = false;
			var saw = false;
			string? sync_text = null;
			st_clipboard_get_text(clipboard, type, (clip, text) => {
				if (!armed) {
					saw = true;
					sync_text = text;
					return;
				}
				this.emit_text(row, text);
			});
			armed = true;
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
			if (saw) {
				this.emit_text(row, sync_text);
			}
		}

		/**
		 * {@code Gsr-St-Clipboard.set_content}. Pixels or a png sit on
		 * {@link OLLMrpc.Request.buffer}.
		 */
		public void set_content(
			OLLMrpc.Request request,
			int type,
			string mimetype,
			int64 nbytes
		) {
			var clipboard = (GLib.Object) request.connection.leases.get(
				(int) request.lease_id);
			var got = request.buffer != null ? request.buffer.fd : -1;
			if (clipboard == null || got < 0 || nbytes < 0 || mimetype == null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS);
				return;
			}
			var buf = new uint8[nbytes];
			Posix.lseek(got, 0, Posix.SEEK_SET);
			var nread = 0;
			while (nread < nbytes) {
				var n = Posix.read(got, (void*) &buf[nread], (size_t) (nbytes - nread));
				if (n <= 0) {
					break;
				}
				nread += (int) n;
			}
			if (nread != nbytes) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR);
				return;
			}
			st_clipboard_set_content(clipboard, type, mimetype, new GLib.Bytes(buf));
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		private void emit_text(OLLMrpc.Live.Hook row, string? text)
		{
			var has = text != null;
			row.emit(OLLMrpc.args("bs", has, has ? text : ""));
		}
	}
}
