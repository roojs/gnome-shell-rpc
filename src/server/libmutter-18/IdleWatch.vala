/**
 * Server peer for {@code meta_idle_monitor_add_idle_watch_full}.
 *
 * {@link IdleMonitor} already relays {@code add_idle_watch} without
 * flags. Shell 50's break timer passes
 * {@code UNINHIBITABLE | START_NOW}. This subclass adds that method
 * on the same wire prefix. The 16 build does not compile this file.
 *
 * == Example ==
 *
 * {{{
 * Gsr.Server.Meta.IdleWatch.rpc_register();
 * }}}
 */
namespace Gsr.Server.Meta
{
	public class IdleWatch : IdleMonitor
	{
		public static new void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Gsr-Mutter-IdleMonitor", typeof(IdleWatch),
				"add_idle_watch_full", "ttu",
				null
			);
			OLLMrpc.Request.register_live(
				"Gsr-Mutter-IdleMonitor", new IdleWatch());
		}

		/**
		 * ''Gsr-Mutter-IdleMonitor.add_idle_watch_full'' — stock
		 * {@code meta_idle_monitor_add_idle_watch_full}.
		 *
		 * @param request inbound RPC; lease is the monitor
		 * @param interval_msec idle interval
		 * @param callback_id client callback row
		 * @param flags {@link global::Meta.IdleMonitorWatchFlags}
		 */
		public void add_idle_watch_full(
			OLLMrpc.Request request,
			uint64 interval_msec,
			uint64 callback_id,
			uint flags
		) {
			var monitor = (global::Meta.IdleMonitor) request.connection.leases.get(
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
			var watch_id = monitor.add_idle_watch_full(
				interval_msec,
				(mon, id) => {
					row.emit(OLLMrpc.args("tu", row.connection.export(mon), id));
				},
				(global::Meta.IdleMonitorWatchFlags) flags
			);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("u", watch_id)
			});
		}
	}
}
