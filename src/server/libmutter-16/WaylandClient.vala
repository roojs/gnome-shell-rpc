/**
 * Delivers {@link Meta.WaylandClient} Override RPC.
 *
 * Wire prefix ''Helper-WaylandClient''. Each create exports **this** helper
 * row (launcher + mutter peer). Instance methods run with that row as
 * {@code self} — no {@code request.lease_id} lookup of the Meta peer.
 *
 * {@code Gio.SubprocessLauncher} stays compositor-side (flags + cwd on wire).
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class WaylandClient : GLib.Object
	{
		private Meta.WaylandClient? peer = null;
		private GLib.SubprocessLauncher? launcher = null;
		private GLib.Subprocess? subprocess = null;

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-WaylandClient", typeof(WaylandClient),
				"create", "ou",
				/* ''as'' = one FFI pointer (null-terminated). ''S'' would
				 * pass get_boxed().length which is -1 after wire decode. */
				"spawnv", "osas",
				"wait", "",
				"get_if_exited", "",
				"get_exit_status", "",
				"send_signal", "i",
				"force_exit", "",
				null
			);
			/* Not register_live — Ffi must bind lease_id → this row as self. */
			OLLMrpc.Request.register(
				"Helper-WaylandClient", new WaylandClient()
			);
		}

		/**
		 * ''Helper-WaylandClient.create'' — mint a helper row + mutter peer.
		 * Reply lease id in {@link OLLMrpc.Response.args} (same as Background).
		 */
		public void create(
			OLLMrpc.Request request,
			Meta.Context context,
			uint flags
		) {
			if (context == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED(
						"Helper-WaylandClient.create: context is null"
					)
				);
				return;
			}
			var row = new WaylandClient();
			row.launcher = new GLib.SubprocessLauncher(
				(GLib.SubprocessFlags) flags
			);
			try {
				row.peer = new Meta.WaylandClient(context, row.launcher);
			} catch (GLib.Error e) {
				request.connection.reply_error(
					request, (int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e
				);
				return;
			}
			var handle = (uint64) request.connection.export(row);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		/**
		 * ''Helper-WaylandClient.spawnv'' — {@code this} is the leased row.
		 * Typed Ffi {@code osas}: {@code as} is one pointer — match with
		 * null-terminated argv (length-bearing needs Ffi {@code S}, but wire
		 * {@code get_boxed().length} is {@code -1}).
		 */
		public void spawnv(
			OLLMrpc.Request request,
			Meta.Display display,
			string cwd,
			[CCode (array_length = false, array_null_terminated = true)]
			string[] argv
		) {
			if (this.peer == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED(
						"Helper-WaylandClient.spawnv: no peer (create row?)"
					)
				);
				return;
			}
			if (display == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED(
						"Helper-WaylandClient.spawnv: display is null"
					)
				);
				return;
			}
			string[] wire = {};
			if (argv != null) {
				for (int i = 0; argv[i] != null; i++) {
					wire += argv[i];
				}
			}
			GLib.message(
				"Helper-WaylandClient.spawnv argv_len=%d cwd='%s'",
				wire.length, cwd ?? "(null)"
			);
			if (this.launcher != null && cwd != null && cwd.length > 0) {
				this.launcher.set_cwd(cwd);
			}
			GLib.Subprocess? proc = null;
			try {
				proc = this.peer.spawnv(display, wire);
			} catch (GLib.Error e) {
				request.connection.reply_error(
					request, (int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e
				);
				return;
			}
			if (proc == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR,
					new GLib.IOError.FAILED("WaylandClient.spawnv returned null")
				);
				return;
			}
			this.subprocess = proc;
			var stdout = proc.get_stdout_pipe();
			int fd = -1;
			if (stdout != null) {
				var unix_out = stdout as GLib.UnixInputStream;
				if (unix_out != null) {
					fd = unix_out.get_fd();
					fd = Posix.dup(fd);
				} else {
					GLib.warning(
						"Helper-WaylandClient.spawnv stdout type=%s "
						+ "(not UnixInputStream)",
						stdout.get_type().name()
					);
				}
			} else {
				GLib.warning(
					"Helper-WaylandClient.spawnv get_stdout_pipe null"
				);
			}
			GLib.message(
				"Helper-WaylandClient.spawnv stdout_fd=%d", fd
			);
			var response = new OLLMrpc.Response() {
				id = request.id,
			};
			if (fd >= 0) {
				request.reply(response, new OLLMrpc.Live.Buffer(fd));
				return;
			}
			request.reply(response);
		}

		public void wait(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED("WaylandClient.wait: no subprocess")
				);
				return;
			}
			proc.wait_async.begin(null, (obj, res) => {
				try {
					proc.wait_async.end(res);
				} catch (GLib.Error e) {
					request.connection.reply_error(
						request, (int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e
					);
					return;
				}
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", true),
				});
			});
		}

		public void get_if_exited(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", false),
				});
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", proc.get_if_exited()),
			});
		}

		public void get_exit_status(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			int status = 0;
			if (proc != null && proc.get_if_exited()) {
				status = proc.get_exit_status();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("i", status),
			});
		}

		public void send_signal(OLLMrpc.Request request, int signum)
		{
			var proc = this.subprocess;
			if (proc != null) {
				proc.send_signal(signum);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void force_exit(OLLMrpc.Request request)
		{
			var proc = this.subprocess;
			if (proc != null) {
				proc.force_exit();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
