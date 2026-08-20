/**
 * Sync RPC helpers for generated GI stubs (plan 0.5 emit).
 *
 * Generated wrappers call {@link call_utf8}; this type owns the client.
 *
 * == Example ==
 *
 * {{{
 * var reply = GnomeShellRpc.GiStub.Runtime.call_utf8("RPC-GiRpcSmoke.ping", "hello");
 * }}}
 */
namespace GnomeShellRpc.GiStub
{
	public class Runtime : GLib.Object
	{
		private static OLLMrpc.Client rpc_client;
		private static bool connected = false;

		/**
		 * Connect once, then {@code RPC-*.method} with a single utf8 {@code msg}.
		 *
		 * @param method full wire method (e.g. {@code RPC-GiRpcSmoke.ping})
		 * @param msg string argument
		 * @return {@link GiRpcSmoke.PingResult.reply} from the server
		 */
		public static string call_utf8(string method, string msg)
		{
			if (!Runtime.connected) {
				GiRpcSmoke.PingParams.rpc_register();
				GiRpcSmoke.PingResult.rpc_register();
				GnomeShellRpc.Rpc.DaemonParams.rpc_register();
				OLLMrpc.Daemon.rpc_register();

				var socket_path = GLib.Environment.get_variable("GI_RPC_SMOKE_SOCKET");
				if (socket_path == null || socket_path.length == 0) {
					var runtime = GLib.Environment.get_variable("XDG_RUNTIME_DIR");
					if (runtime != null && runtime.length > 0) {
						socket_path = GLib.Path.build_filename(runtime, "gi-rpc-smoke.sock");
					} else {
						socket_path = "/tmp/gi-rpc-smoke.sock";
					}
				}
				GLib.debug("socket path %s", socket_path);

				Runtime.rpc_client = new OLLMrpc.Client("", "", socket_path) {
					live_handles = false,
					debug = false,
				};

				var connect_ok = false;
				var connect_err = "";
				var connect_loop = new GLib.MainLoop();
				Runtime.rpc_client.connect.begin(new OLLMrpc.Request() {
					method = "RPC-Daemon.hello",
					param = new GnomeShellRpc.Rpc.DaemonParams() {
						protocol = 1,
						client = "gi-rpc-smoke",
					},
				}, null, (obj, res) => {
					connect_ok = Runtime.rpc_client.connect.end(res);
					if (!connect_ok) {
						connect_err = Runtime.rpc_client.connect_error;
					}
					connect_loop.quit();
				});
				connect_loop.run();
				if (!connect_ok) {
					GLib.error("%s", connect_err);
				}
				Runtime.connected = true;
			}

			OLLMrpc.Response? response = null;
			GLib.Error? call_error = null;
			var call_loop = new GLib.MainLoop();
			Runtime.rpc_client.call.begin(new OLLMrpc.Request() {
				method = method,
				param = new GiRpcSmoke.PingParams() {
					msg = msg,
				},
			}, (obj, res) => {
				try {
					response = Runtime.rpc_client.call.end(res);
				} catch (GLib.Error e) {
					call_error = e;
				}
				call_loop.quit();
			});
			call_loop.run();
			if (call_error != null) {
				GLib.error("%s", call_error.message);
			}
			if (response.error != null) {
				GLib.error("%s", response.error.message);
			}
			var row = (GiRpcSmoke.PingResult)response.result.get(0);
			return row.reply;
		}
	}
}
