/**
 * Server helpers that deliver Override RPC (plan 0.5.7).
 *
 * Call {@link rpc_register} once from the compositor boot path so every
 * Helper wire prefix and live singleton is registered.
 *
 * == Example ==
 *
 * {{{
 * Gsr.Server.rpc_register(gate);
 * }}}
 */
namespace Gsr.Server
{
	/**
	 * Register all Override Helpers (wire tables + live singletons).
	 *
	 * @param gate startup frame lock shared with global::Meta.Context
	 */
	public void rpc_register(StartupFrameLock gate)
	{
		LiveCallback.rpc_register();
		Daemon.rpc_register();
		Bootstrap.rpc_register();
		Cancellable.rpc_register();
		Meta.rpc_register(gate);
		Clutter.rpc_register();
		St.rpc_register();
		Shell.rpc_register();
	}
}
