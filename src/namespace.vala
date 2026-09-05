/**
 * Nested mutter compositor exposing desktop state over GObject RPC.
 *
 * {@link Plugin} is the in-process {@link Meta.Plugin}. The process starts
 * a {@link Meta.Context} the same way Gala does: the Vala binary links
 * libmutter and calls {@link Meta.Context.set_plugin_gtype}. Stock mutter
 * is not loaded with `--mutter-plugin` yet.
 *
 * {@link GnomeShellRpc.Ui} types are the remote representation of what the
 * user sees. {@link GnomeShellRpc.Rpc.Server} listens on a Unix socket.
 *
 * == Example ==
 *
 * {{{
 * dbus-run-session ./build/src/mutter-rpc --wayland --nested
 * }}}
 */
namespace GnomeShellRpc
{
#if GSR_GI_STUB
	/**
	 * Sync RPC call with positional {@link GLib.Value}s and optional instance.
	 *
	 * @param method wire method (e.g. {@code Meta-Window.minimize})
	 * @param instance leased stub; {@link OLLMrpc.Live.Handle.rpc_lid}
	 *     → {@link OLLMrpc.Request.lease_id}
	 * @param args GIR-order IN / INOUT args from {@link OLLMrpc.args}
	 */
	public OLLMrpc.Response call_value(
		string method,
		GLib.Object? instance = null,
		Gee.ArrayList<GLib.Value?>? args = null
	) throws GLib.Error {
		uint64 lease_id = 0;
		if (instance != null) {
			lease_id = GiStub.Runtime.lease_id_of(instance, method);
		}
		var req = new OLLMrpc.Request() {
			method = method,
			lease_id = lease_id,
		};
		if (args == null) {
			return GiStub.Runtime.do_call(req);
		}
		foreach (var val in args) {
			if (!val.type().is_a(GLib.Type.OBJECT)) {
				req.args.add(val);
				continue;
			}
			var obj = val.get_object();
			if (obj == null) {
				var zero = GLib.Value(GLib.Type.UINT64);
				zero.set_uint64(0);
				req.args.add(zero);
				continue;
			}
			var lease = GiStub.Runtime.lease_id_of(obj, method);
			var wire = GLib.Value(GLib.Type.UINT64);
			wire.set_uint64(lease);
			req.args.add(wire);
		}
		return GiStub.Runtime.do_call(req);
	}
#endif
}
