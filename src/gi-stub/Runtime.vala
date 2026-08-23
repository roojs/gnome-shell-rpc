/**
 * Sync RPC client for GI stubs (plan 0.5 Meta mini).
 *
 * {@link register} is idempotent (wire types + {@code MUTTER_RPC_SOCKET}).
 * {@link call} and {@link call_values} always start with {@link register}.
 *
 * Positional args use {@link OLLMrpc.Request.values} (GIR order, no direction
 * on the wire). Leased instance methods set {@link OLLMrpc.Request.lease_id}.
 * Scalar returns land in {@link OLLMrpc.Response.values}; GObjects in
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
 * GnomeShellRpc.GiStub.Runtime.call_void_values(
 *     "Meta-Window.minimize",
 *     3);
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
		 * Sync call with a typed {@link OLLMrpc.CallParam} bag (legacy path).
		 */
		public static OLLMrpc.Response call(string method, OLLMrpc.CallParam param)
		{
			return Runtime.do_call(new OLLMrpc.Request() {
				method = method,
				param = param,
			});
		}

		/**
		 * Sync call with positional {@link GLib.Value}s and optional lease.
		 *
		 * @param method wire method (e.g. {@code Meta-Window.minimize})
		 * @param lease_id leased instance handle; {@code 0} for constructors / no instance
		 * @param values GIR-order IN / INOUT args (may be empty)
		 */
		public static OLLMrpc.Response call_values(
			string method,
			uint64 lease_id = 0,
			owned GLib.Value?[]? values = null
		) {
			var req = new OLLMrpc.Request() {
				method = method,
				lease_id = lease_id,
			};
			if (values != null) {
				foreach (unowned var val in values) {
					req.values.add(val);
				}
			}
			return Runtime.do_call(req);
		}

		/**
		 * Positional call with no return payload (void method).
		 */
		public static void call_void_values(
			string method,
			uint64 lease_id = 0,
			owned GLib.Value?[]? values = null
		) {
			Runtime.call_values(method, lease_id, values);
		}

		/**
		 * {@link call} then first {@link OLLMrpc.Response.result} row, or null.
		 */
		public static GLib.Object? call_object(
			string method,
			OLLMrpc.CallParam param,
			GLib.Type expected
		) {
			return Runtime.first_object(Runtime.call(method, param), expected);
		}

		/**
		 * {@link call_values} then first {@link OLLMrpc.Response.result} row, or null.
		 */
		public static GLib.Object? call_object_values(
			string method,
			uint64 lease_id,
			GLib.Type expected,
			owned GLib.Value?[]? values = null
		) {
			return Runtime.first_object(
				Runtime.call_values(method, lease_id, values),
				expected
			);
		}

		/**
		 * {@link call} then every {@link OLLMrpc.Response.result} row.
		 */
		public static GLib.List<GLib.Object> call_list(
			string method,
			OLLMrpc.CallParam param,
			GLib.Type elem
		) {
			return Runtime.object_list(Runtime.call(method, param), elem);
		}

		/**
		 * {@link call_values} then scalar int at {@code index} in {@link OLLMrpc.Response.values}.
		 */
		public static int call_int_values(
			string method,
			uint64 lease_id = 0,
			int index = 0,
			owned GLib.Value?[]? values = null
		) {
			return Runtime.scalar_int(
				Runtime.call_values(method, lease_id, values),
				index
			);
		}

		/**
		 * {@link call_values} then scalar string at {@code index}.
		 */
		public static string call_string_values(
			string method,
			uint64 lease_id = 0,
			int index = 0,
			owned GLib.Value?[]? values = null
		) {
			return Runtime.scalar_string(
				Runtime.call_values(method, lease_id, values),
				index
			);
		}

		/**
		 * First {@link OLLMrpc.Response.result} row cast to {@code expected}, or null.
		 */
		public static GLib.Object? first_object(
			OLLMrpc.Response response,
			GLib.Type expected
		) {
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
		 * Every {@link OLLMrpc.Response.result} row cast to {@code elem}.
		 */
		public static GLib.List<GLib.Object> object_list(
			OLLMrpc.Response response,
			GLib.Type elem
		) {
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

		/**
		 * Scalar int from {@link OLLMrpc.Response.values} at {@code index}.
		 */
		public static int scalar_int(OLLMrpc.Response response, int index = 0)
		{
			if (index < 0 || index >= response.values.size) {
				GLib.error("RPC values[%d]: out of range (size %d)", index, response.values.size);
			}
			return response.values.get(index).get_int();
		}

		/**
		 * Scalar string from {@link OLLMrpc.Response.values} at {@code index}.
		 */
		public static string scalar_string(OLLMrpc.Response response, int index = 0)
		{
			if (index < 0 || index >= response.values.size) {
				GLib.error("RPC values[%d]: out of range (size %d)", index, response.values.size);
			}
			return response.values.get(index).get_string();
		}

		/** Box an int for {@link call_values}. */
		public static GLib.Value value_int(int v)
		{
			var val = GLib.Value(typeof(int));
			val.set_int(v);
			return val;
		}

		/** Box a string for {@link call_values}. */
		public static GLib.Value value_string(string s)
		{
			var val = GLib.Value(typeof(string));
			val.set_string(s);
			return val;
		}

		/** Box a bool for {@link call_values}. */
		public static GLib.Value value_bool(bool v)
		{
			var val = GLib.Value(typeof(bool));
			val.set_boolean(v);
			return val;
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
			return response;
		}
	}
}
