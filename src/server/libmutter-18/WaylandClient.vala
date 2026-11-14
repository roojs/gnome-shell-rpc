/**
 * Delivers {@link global::Meta.WaylandClient} for mutter 18.
 *
 * Wire prefix ''Gsr-Mutter-WaylandClient''. Mutter 18 launches in
 * {@code new_subprocess}; there is no {@code spawnv} and no display
 * argument. The helper row is the lease, same as the 16 file.
 * The 16 build does not compile this file. The 18 startup calls
 * {@link rpc_register}.
 */
namespace Gsr.Server.Meta
{
	public class WaylandClient : GLib.Object
	{
		private global::Meta.WaylandClient? peer = null;
		private GLib.Subprocess? subprocess = null;
		private bool exited = false;

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Mutter-WaylandClient", typeof(WaylandClient),
				/* ''as'' = one FFI pointer (null-terminated). ''S'' would
				 * pass get_boxed().length which is -1 after wire decode. */
				"new_subprocess", "ousas",
				"wait", "",
				"get_if_exited", "",
				"get_exit_status", "",
				"send_signal", "i",
				"force_exit", "",
				"owns_window", "o",
				null
			);
			/* Not register_live — Ffi must bind lease_id → this row as self. */
			OLLMrpc.Request.register(
				"Gsr-Mutter-WaylandClient", new WaylandClient()
			);
			/* After IdleMonitor.rpc_register. Same startup, 18 only. */
			Keymap.rpc_register();
			IdleWatch.rpc_register();
			Gsr.Server.St.DndStart.rpc_register();
		}

		/**
		 * ''Gsr-Mutter-WaylandClient.new_subprocess'' — launcher stays
		 * here. Wire is context, flags, cwd, argv. Reply lease is in
		 * {@link OLLMrpc.Response.args}. Stdout, when the flags asked
		 * for a pipe, is the memfd buffer.
		 */
		public void new_subprocess(
			OLLMrpc.Request request,
			global::Meta.Context context,
			uint flags,
			string cwd,
			[CCode (array_length = false, array_null_terminated = true)]
			string[] argv
		) {
			if (context == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED(
						"Gsr-Mutter-WaylandClient.new_subprocess: context is null"
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
			var row = new WaylandClient();
			var launcher = new GLib.SubprocessLauncher(
				(GLib.SubprocessFlags) flags
			);
			if (cwd != null && cwd.length > 0) {
				launcher.set_cwd(cwd);
			}
			try {
				row.peer = new global::Meta.WaylandClient.subprocess(
					context, launcher, wire
				);
			} catch (GLib.Error e) {
				launcher.close();
				request.connection.reply_error(
					request, (int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e
				);
				return;
			}
			launcher.close();
			row.subprocess = row.peer.get_subprocess();
			row.subprocess.wait_async.begin(null, (obj, res) => {
				try {
					row.subprocess.wait_async.end(res);
				} catch (GLib.Error e) {
				}
				row.exited = true;
			});
			var handle = (uint64) request.connection.export(row);
			var response = new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			};
			var stdout = row.subprocess.get_stdout_pipe();
			var unix_out = stdout as GLib.UnixInputStream;
			if (unix_out != null) {
				var fd = Posix.dup(unix_out.get_fd());
				request.reply(response, new OLLMrpc.Live.Buffer(fd));
				return;
			}
			if (stdout == null) {
				GLib.warning(
					"Gsr-Mutter-WaylandClient.new_subprocess get_stdout_pipe null"
				);
				request.reply(response);
				return;
			}
			GLib.warning(
				"Gsr-Mutter-WaylandClient.new_subprocess stdout type=%s "
				+ "(not UnixInputStream)",
				stdout.get_type().name()
			);
			request.reply(response);
		}

		public void wait(OLLMrpc.Request request)
		{
			if (this.subprocess == null) {
				request.connection.reply_error(
					request,
					(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
					new GLib.IOError.FAILED("WaylandClient.wait: no subprocess")
				);
				return;
			}
			var connection = request.connection;
			var lease_id = (int) request.lease_id;
			if (this.exited) {
				connection.write(new OLLMrpc.Notification() {
					method = "WaylandClient.exited",
					id = lease_id,
				});
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", true),
				});
				return;
			}
			this.subprocess.wait_async.begin(null, (obj, res) => {
				try {
					this.subprocess.wait_async.end(res);
				} catch (GLib.Error e) {
					GLib.warning("wait failed: %s", e.message);
				}
				this.exited = true;
				connection.write(new OLLMrpc.Notification() {
					method = "WaylandClient.exited",
					id = lease_id,
				});
			});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", true),
			});
		}

		public void get_if_exited(OLLMrpc.Request request)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b",
					this.subprocess != null
					&& this.exited
					&& this.subprocess.get_if_exited()),
			});
		}

		public void get_exit_status(OLLMrpc.Request request)
		{
			var status = 0;
			if (this.subprocess != null && this.exited && this.subprocess.get_if_exited()) {
				status = this.subprocess.get_exit_status();
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

		/**
		 * ''Gsr-Mutter-WaylandClient.owns_window'' — stock
		 * {@code meta_wayland_client_owns_window}. Desktop Icons
		 * uses this from {@code Shell.WM::map} before it lowers
		 * the desktop window.
		 */
		public void owns_window(
			OLLMrpc.Request request,
			global::Meta.Window window
		) {
			if (this.peer == null || window == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					retval = OLLMrpc.val("b", false),
				});
				return;
			}
			bool owns = false;
			try {
				owns = this.peer.owns_window(window);
			} catch (GLib.Error e) {
				owns = false;
			}
			/* Stock pointer check misses a window this process opened
			 * on the session socket. Desktop Icons then kills the
			 * process and launches a second one.
			 */
			if (!owns) {
				var pid = this.peer.get_pid();
				if (pid != 0 && window.get_pid() == pid) {
					owns = true;
				}
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", owns),
			});
		}
	}
}
