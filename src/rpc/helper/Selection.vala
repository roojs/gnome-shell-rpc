/**
 * Delivers {@link Meta.Selection} Override RPC (plan 0.5.5 F).
 *
 * Wire prefix ''Helper-Selection''. Lease is the selection.
 * {@link transfer} runs mutter's async transfer into a memory stream on the
 * compositor, then replies with the bytes on {@link OLLMrpc.Request.reply}'s
 * buffer (same memfd pattern as paint).
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class Selection : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-Selection", typeof(Selection),
				"transfer", "isxt",
				null
			);
			OLLMrpc.Request.register_live("Helper-Selection",
				new Selection());
		}

		public void transfer(
			OLLMrpc.Request request,
			int selection_type,
			string mimetype,
			int64 size,
			uint64 cancel_id
		) {
			var selection = (Meta.Selection) request.connection.leases.get(
				(int) request.lease_id);
			var stream = new GLib.MemoryOutputStream.resizable();
			var cancel = GnomeShellRpc.Rpc.CancellableBridge.lookup(cancel_id);
			var loop = new GLib.MainLoop();
			GLib.Error? err = null;
			var ok = false;
			selection.transfer_async.begin((Meta.SelectionType) selection_type,
				mimetype, (ssize_t) size, stream, cancel, (obj, res) => {
					try {
						ok = selection.transfer_async.end(res);
					} catch (GLib.Error e) {
						err = e;
					}
					loop.quit();
				});
			loop.run();
			if (err != null) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, err);
				return;
			}
			if (!ok) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					args = OLLMrpc.args("b", false),
				});
				return;
			}
			var bytes = stream.steal_as_bytes();
			var data = bytes.get_data();
			string path;
			GLib.IOStream iostream;
			try {
				var file = GLib.File.new_tmp("gsr-sel-XXXXXX", out iostream);
				path = file.get_path();
				size_t written;
				iostream.output_stream.write_all(data, out written);
				iostream.close();
			} catch (GLib.Error e) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e);
				return;
			}
			var fd = Posix.open(path, Posix.O_RDONLY);
			GLib.FileUtils.unlink(path);
			if (fd < 0) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					args = OLLMrpc.args("b", false),
				});
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("bx", true, (int64) data.length),
			}, new OLLMrpc.Live.Buffer(fd));
		}
	}
}
