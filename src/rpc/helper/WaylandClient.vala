/**
 * Delivers {@link Meta.WaylandClient} Override RPC.
 *
 * Wire prefix ''Helper-WaylandClient''. {@code Gio.SubprocessLauncher} is not
 * on the wire — client sends flags (+ cwd at spawn). Compositor builds the
 * real launcher and {@link Meta.WaylandClient}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class WaylandClient : GLib.Object
	{
		private Gee.HashMap<int, GLib.SubprocessLauncher> launchers {
			get; set; default = new Gee.HashMap<int, GLib.SubprocessLauncher>();
		}
		private Gee.HashMap<int, GLib.Subprocess> subprocesses {
			get; set; default = new Gee.HashMap<int, GLib.Subprocess>();
		}
		public static void rpc_register()
		{
			var helper = new WaylandClient();
			OLLMrpc.Request.add_class(
				"Helper-WaylandClient", typeof(WaylandClient),
				"create", "ou",
				"spawnv", "oas",
				"wait", "",
				"get_if_exited", "",
				"get_exit_status", "",
				"send_signal", "i",
				"force_exit", "",
				null
			);
			OLLMrpc.Request.register_live("Helper-WaylandClient", helper);
		}

		/**
		 * ''Helper-WaylandClient.create'' — context lease + launcher flags →
		 * compositor {@link Meta.WaylandClient}.
		 */
		public void create(
			OLLMrpc.Request request,
			Meta.Context context,
			uint flags
		) {
			var launcher = new GLib.SubprocessLauncher(
				(GLib.SubprocessFlags) flags
			);
			Meta.WaylandClient? client = null;
			try {
				client = new Meta.WaylandClient(context, launcher);
			} catch (GLib.Error e) {
				request.connection.reply_error(
					request, (int) OLLMrpc.RpcErrorCode.INTERNAL_ERROR, e
				);
				return;
			}
			var lid = (int) request.connection.export(client);
			this.launchers.set(lid, launcher);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", client),
			});
		}

		/**
		 * ''Helper-WaylandClient.spawnv'' — cwd + argv on the leased client.
		 * Stdout pipe fd on {@link OLLMrpc.Live.Buffer} when present.
		 */
		public void spawnv(
			OLLMrpc.Request request,
			Meta.Display display,
			string cwd,
			string[] argv
		) {
			var lid = (int) request.lease_id;
			var client = (Meta.WaylandClient) request.connection.leases.get(lid);
			var launcher = this.launchers.get(lid);
			if (launcher != null && cwd != null && cwd.length > 0) {
				launcher.set_cwd(cwd);
			}
			GLib.Subprocess? proc = null;
			try {
				proc = client.spawnv(display, argv);
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
			this.subprocesses.set(lid, proc);
			var stdout = proc.get_stdout_pipe();
			int fd = -1;
			if (stdout != null) {
				var unix_out = stdout as GLib.UnixInputStream;
				if (unix_out != null) {
					fd = unix_out.get_fd();
					/* Dup — reply Buffer closes its fd; Subprocess keeps the pipe. */
					fd = Posix.dup(fd);
				}
			}
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
			var lid = (int) request.lease_id;
			var proc = this.subprocesses.get(lid);
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
			var proc = this.subprocesses.get((int) request.lease_id);
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
			var proc = this.subprocesses.get((int) request.lease_id);
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
			var proc = this.subprocesses.get((int) request.lease_id);
			if (proc != null) {
				proc.send_signal(signum);
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		public void force_exit(OLLMrpc.Request request)
		{
			var proc = this.subprocesses.get((int) request.lease_id);
			if (proc != null) {
				proc.force_exit();
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}
	}
}
