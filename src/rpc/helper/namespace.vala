/**
 * Server helpers that deliver Override RPC (plan 0.5.7).
 *
 * Call {@link rpc_register} once from the compositor boot path so every
 * Helper wire prefix and live singleton is registered.
 *
 * == Example ==
 *
 * {{{
 * GnomeShellRpc.Rpc.Helper.rpc_register(gate);
 * }}}
 */
namespace GnomeShellRpc.Rpc.Helper
{
	/**
	 * Register all Override Helpers (wire tables + live singletons).
	 *
	 * @param gate startup frame gate shared with Meta.Context
	 */
	public void rpc_register(StartupFrameGate gate)
	{
		SoundPlayer.rpc_register();
		Background.rpc_register();
		BackgroundImageCache.rpc_register();
		BackgroundActor.rpc_register();
		Context.rpc_register(gate);
		Settings.rpc_register();
		IdleMonitor.rpc_register();
		Display.rpc_register();
		Window.rpc_register();
		WindowActor.rpc_register();
		Selection.rpc_register();
		SelectionSource.rpc_register();
		SelectionSourceMemory.rpc_register();
		ShapedTexture.rpc_register();
		Text.rpc_register();
		ShaderEffect.rpc_register();
		GLSLEffect.rpc_register();
		BlurEffect.rpc_register();
		InvertLightnessEffect.rpc_register();
		ClutterThreads.rpc_register();
		ClutterHelper.rpc_register();
		Barrier.rpc_register();
		OLLMrpc.Bin.TypeOverride.register(new ClutterEventOverride());
		OLLMrpc.Bin.TypeOverride.register(new ActorBoxOverride());
		OLLMrpc.Bin.TypeOverride.register(new InputDeviceOverride());
		Interval.rpc_register();
		Constraint.rpc_register();
		St.rpc_register();
		ThemeContext.rpc_register();
		Icon.rpc_register();
		IconTheme.rpc_register();
		ImageContent.rpc_register();
		FocusManager.rpc_register();
		Actor.rpc_register();
		LayoutManager.rpc_register();
		ClutterPaintContext.rpc_register();
		ClutterStage.rpc_register();
		WaylandClient.rpc_register();
		AppLaunch.rpc_register();
	}
}
