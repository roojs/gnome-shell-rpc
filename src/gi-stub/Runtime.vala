/**
 * Sync RPC client for GI stubs (plan 0.5 Meta mini).
 *
 * {@link register} is idempotent (wire types + {@code MUTTER_RPC_SOCKET}).
 * {@link call_values}, {@link call_object}, and {@link call_list} always start
 * with {@link register}.
 *
 * Positional args use {@link OLLMrpc.Request.values} (GIR order, no direction
 * on the wire). Instance stubs carry {@code gsr-lease-id} data →
 * {@link OLLMrpc.Request.lease_id}. Scalar returns land in {@link OLLMrpc.Response.values}; GObjects in
 * {@link OLLMrpc.Response.result}.
 *
 * == Example ==
 *
 * {{{
 * GnomeShellRpc.GiStub.Runtime.register();
 * var rows = GnomeShellRpc.GiStub.Runtime.call_list(
 *     "Meta-Display.list_windows",
 *     new GnomeShellRpc.Ui.DisplayParams(),
 *     typeof(GnomeShellRpc.Ui.Window));
 * GnomeShellRpc.GiStub.Runtime.call_values("Meta-Window.minimize", win);
 * }}}
 */
namespace GnomeShellRpc.GiStub
{
	public class Runtime : GLib.Object
	{
		private static OLLMrpc.Client client;
		private static bool connected = false;

		/**
		 * Register Ui wire types and connect to {@code MUTTER_RPC_SOCKET}.
		 *
		 * Safe to call repeatedly; returns immediately if already connected.
		 */
		public static void register()
		{
			if (Runtime.connected) {
				return;
			}

			GnomeShellRpc.Shared.Rectangle.rpc_register();
			GnomeShellRpc.Ui.Window.rpc_register();
			GnomeShellRpc.Ui.WindowParams.rpc_register();
			GnomeShellRpc.Ui.DisplayParams.rpc_register();
			GnomeShellRpc.Rpc.DaemonParams.rpc_register();
			GnomeShellRpc.Rpc.BootstrapParams.rpc_register();
			OLLMrpc.Daemon.rpc_register();
			OLLMrpc.Bin.register("CallParam", typeof(OLLMrpc.CallParam));

			var socket_path = GLib.Environment.get_variable("MUTTER_RPC_SOCKET");
			if (socket_path == null || socket_path.length == 0) {
				var runtime = GLib.Environment.get_variable("XDG_RUNTIME_DIR");
				if (runtime != null && runtime.length > 0) {
					socket_path = GLib.Path.build_filename(
						runtime, "mutter-rpc.sock"
					);
				} else {
					socket_path = "/tmp/mutter-rpc.sock";
				}
			}
			GLib.debug("mutter socket path %s", socket_path);

			Runtime.client = new OLLMrpc.Client("", "", socket_path) {
				live_handles = true,
				debug = false,
			};

			var connect_ok = false;
			var connect_err = "";
			var connect_loop = new GLib.MainLoop();
			Runtime.client.connect.begin(new OLLMrpc.Request() {
				method = "RPC-Daemon.hello",
				param = new GnomeShellRpc.Rpc.DaemonParams() {
					protocol = 1,
					client = "meta-mini",
				},
			}, null, (obj, res) => {
				connect_ok = Runtime.client.connect.end(res);
				if (!connect_ok) {
					connect_err = Runtime.client.connect_error;
				}
				connect_loop.quit();
			});
			connect_loop.run();
			if (!connect_ok) {
				GLib.error("%s", connect_err);
			}
			Runtime.connected = true;
		}

		/**
		 * Sync call with positional {@link GLib.Value}s and optional instance.
		 *
		 * @param method wire method (e.g. {@code Meta-Window.minimize})
		 * @param instance leased stub; {@code gsr-lease-id} data → {@link OLLMrpc.Request.lease_id}
		 * @param values GIR-order IN / INOUT args (may be empty)
		 */
		public static OLLMrpc.Response call_values(
			string method,
			GLib.Object? instance = null,
			owned GLib.Value?[]? values = null,
			OLLMrpc.CallParam? param = null
		) {
			uint64 lease_id = 0;
			if (instance != null) {
				var lease = instance.get_data<string>("gsr-lease-id");
				if (lease == null || lease.length == 0) {
					GLib.error(
						"RPC %s: no gsr-lease-id on %s",
						method,
						instance.get_type().name()
					);
				}
				lease_id = uint64.parse(lease);
			}
			var req = new OLLMrpc.Request() {
				method = method,
				lease_id = lease_id,
			};
			if (param != null) {
				req.param = param;
			}
			if (values == null) {
				return Runtime.do_call(req);
			}
			foreach (unowned var val in values) {
				if (!val.type().is_a(GLib.Type.OBJECT)) {
					req.values.add(val);
					continue;
				}
				var obj = val.get_object();
				if (obj == null) {
					var zero = GLib.Value(GLib.Type.UINT64);
					zero.set_uint64(0);
					req.values.add(zero);
					continue;
				}
				var lease = obj.get_data<string>("gsr-lease-id");
				if (lease == null || lease.length == 0) {
					GLib.error(
						"RPC %s: cannot serialize %s (not a leased stub)",
						method,
						val.type().name()
					);
				}
				var wire = GLib.Value(GLib.Type.UINT64);
				wire.set_uint64(uint64.parse(lease));
				req.values.add(wire);
			}
			return Runtime.do_call(req);
		}

		/**
		 * Legacy {@link OLLMrpc.CallParam} call; first {@link OLLMrpc.Response.result}
		 * row, or null.
		 */
		public static GLib.Object? call_object(
			string method,
			OLLMrpc.CallParam param,
			GLib.Type expected
		) {
			var response = Runtime.do_call(new OLLMrpc.Request() {
				method = method,
				param = param,
			});
			if (response.result.size == 0) {
				return null;
			}
			var obj = response.result.get(0);
			if (!obj.get_type().is_a(expected)) {
				GLib.error(
					"RPC %s: expected %s, got %s",
					"result[0]",
					expected.name(),
					obj.get_type().name()
				);
			}
			return obj;
		}

		/**
		 * Legacy {@link OLLMrpc.CallParam} call; every {@link OLLMrpc.Response.result}
		 * row.
		 */
		public static GLib.List<GLib.Object> call_list(
			string method,
			OLLMrpc.CallParam param,
			GLib.Type elem
		) {
			var response = Runtime.do_call(new OLLMrpc.Request() {
				method = method,
				param = param,
			});
			var list = new GLib.List<GLib.Object>();
			for (var i = 0; i < response.result.size; i++) {
				var obj = response.result.get(i);
				if (!obj.get_type().is_a(elem)) {
					GLib.error(
						"RPC result[%d]: expected %s, got %s",
						i,
						elem.name(),
						obj.get_type().name()
					);
				}
				list.append(obj);
			}
			return list;
		}

		private static OLLMrpc.Response do_call(OLLMrpc.Request request)
		{
			Runtime.register();

			OLLMrpc.Response? response = null;
			GLib.Error? call_error = null;
			var call_loop = new GLib.MainLoop();
			Runtime.client.call.begin(request, (obj, res) => {
				try {
					response = Runtime.client.call.end(res);
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
			for (var i = 0; i < response.result.size; i++) {
				var obj = response.result.get(i);
				var lease = obj.get_data<string>("gsr-lease-id");
				if (lease != null && lease.length > 0) {
					continue;
				}
				foreach (var entry in Runtime.client.proxies) {
					if (entry.value == obj) {
						obj.set_data("gsr-lease-id", entry.key.to_string());
						break;
					}
				}
			}
			return response;
		}
	}
}
