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
		[CCode (cname = "memfd_create", cheader_filename = "sys/mman.h")]
		private static extern int memfd_create(string name, uint flags);

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
			selection.transfer_async.begin((Meta.SelectionType) selection_type,
				mimetype, (ssize_t) size, stream, cancel, (obj, res) => {
					GLib.Error? err = null;
					var ok = false;
					try {
						ok = selection.transfer_async.end(res);
					} catch (GLib.Error e) {
						err = e;
					}
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
					var fd = memfd_create("gsr-sel", 1);
					if (fd < 0 || Posix.write(fd, data, data.length) != data.length) {
						if (fd >= 0) {
							Posix.close(fd);
						}
						request.reply(new OLLMrpc.Response() {
							id = request.id,
							args = OLLMrpc.args("b", false),
						});
						return;
					}
					Posix.lseek(fd, 0, Posix.SEEK_SET);
					request.reply(new OLLMrpc.Response() {
						id = request.id,
						args = OLLMrpc.args("bx", true, (int64) data.length),
					}, new OLLMrpc.Live.Buffer(fd));
				});
		}
	}
}
