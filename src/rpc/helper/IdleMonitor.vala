/**
 * Delivers {@link Meta.IdleMonitor} Override RPC (plan 0.5.6 B2).
 *
 * Wire prefix ''Helper-IdleMonitor''. Lease is the monitor.
 * Mutter Vala hides GIR user_data / notify; the trampoline is an
 * {@link Meta.IdleMonitorWatchFunc} that captures the {@link OLLMrpc.Live.Hook}.
 */
namespace GnomeShellRpc.Rpc.Helper
{
	public class IdleMonitor : GLib.Object
	{
		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Helper-IdleMonitor", typeof(IdleMonitor),
				"add_idle_watch", "tt",
				"add_user_active_watch", "t",
				null
			);
			OLLMrpc.Request.register_live("Helper-IdleMonitor", new IdleMonitor());
		}

		public void add_idle_watch(
			OLLMrpc.Request request,
			uint64 interval_msec,
			uint64 callback_id
		) {
			var monitor = (Meta.IdleMonitor) request.connection.leases.get(
				(int) request.lease_id);
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					error = new OLLMrpc.Error(
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
						"unknown callback id"
					),
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			var watch_id = monitor.add_idle_watch(interval_msec, (mon, id) => {
				row.emit(OLLMrpc.args("tu", row.connection.export(mon), id));
			});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("u", watch_id)
			});
		}

		public void add_user_active_watch(
			OLLMrpc.Request request,
			uint64 callback_id
		) {
			var monitor = (Meta.IdleMonitor) request.connection.leases.get(
				(int) request.lease_id);
			if (!request.connection.callbacks.has_key((int) callback_id)) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					error = new OLLMrpc.Error(
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
						"unknown callback id"
					),
				});
				return;
			}
			var row = request.connection.callbacks.get((int) callback_id);
			var watch_id = monitor.add_user_active_watch((mon, id) => {
				row.emit(OLLMrpc.args("tu", row.connection.export(mon), id));
			});
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("u", watch_id)
			});
		}
	}
}
