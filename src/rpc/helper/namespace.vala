/**
 * Server helpers that deliver Override RPC (plan 0.5.7).
 *
 * Call {@link rpc_register} once from the compositor boot path so every
 * Helper wire prefix and live singleton is registered.
 *
 * == Example ==
 *
 * {{{
 * GnomeShellRpc.Rpc.Helper.rpc_register();
 * }}}
 */
namespace GnomeShellRpc.Rpc.Helper
{
	/**
	 * Register all Override Helpers (wire tables + live singletons).
	 */
	public void rpc_register()
	{
		SoundPlayer.rpc_register();
		Background.rpc_register();
		Context.rpc_register();
		Settings.rpc_register();
		IdleMonitor.rpc_register();
		Display.rpc_register();
		Window.rpc_register();
		WindowActor.rpc_register();
		Selection.rpc_register();
		SelectionSource.rpc_register();
		SelectionSourceMemory.rpc_register();
		ShapedTexture.rpc_register();
		ShaderEffect.rpc_register();
		ClutterThreads.rpc_register();
		ClutterActor.rpc_register();
		ClutterContext.rpc_register();
		ClutterPaintContext.rpc_register();
		ClutterStage.rpc_register();
	}
}
