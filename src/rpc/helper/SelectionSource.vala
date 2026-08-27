/**
 * Delivers {@link Meta.SelectionSource} Override RPC (plan 0.5.5 F).
 *
 * Wire prefix ''Helper-SelectionSource''. Lease is the source.
 * {@link read} finishes mutter's async read on the compositor and replies
 * with the payload memfd.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class SelectionSource : GLib.Object
	{
		public static void register()
		{
			OLLMrpc.Request.add_class(
				"Helper-SelectionSource", typeof(SelectionSource),
				"read", "st",
				null
			);
			OLLMrpc.Request.register_live("Helper-SelectionSource",
				new SelectionSource());
		}

		public void read(
			OLLMrpc.Request request,
			string mimetype,
			uint64 cancel_id
		) {
			var source = (Meta.SelectionSource) request.connection.leases.get(
				(int) request.lease_id);
			var cancel = GnomeShellRpc.Rpc.CancellableBridge.lookup(cancel_id);
			var loop = new GLib.MainLoop();
			GLib.Error? err = null;
			GLib.InputStream? input = null;
			source.read_async.begin(mimetype, cancel, (obj, res) => {
				try {
					input = source.read_async.end(res);
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
			if (input == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					args = OLLMrpc.args("b", false),
				});
				return;
			}
			var mem = new GLib.MemoryOutputStream.resizable();
			try {
				mem.splice(input,
					GLib.OutputStreamSpliceFlags.CLOSE_SOURCE
					| GLib.OutputStreamSpliceFlags.CLOSE_TARGET,
					null);
			} catch (GLib.Error e) {
				request.connection.reply_error(request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e);
				return;
			}
			var bytes = mem.steal_as_bytes();
			var data = bytes.get_data();
			string path;
			GLib.IOStream iostream;
			try {
				var file = GLib.File.new_tmp("gsr-selsrc-XXXXXX", out iostream);
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
