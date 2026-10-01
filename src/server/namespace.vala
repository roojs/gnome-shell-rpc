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
	 * @param gate startup frame gate shared with global::Meta.Context
	 */
	public void rpc_register(StartupFrameGate gate)
	{
		Meta.SoundPlayer.rpc_register();
		Meta.Background.rpc_register();
		Meta.BackgroundImageCache.rpc_register();
		Meta.BackgroundActor.rpc_register();
		Meta.Context.rpc_register(gate);
		Meta.Settings.rpc_register();
		Meta.IdleMonitor.rpc_register();
		Meta.Keybinding.rpc_register();
		Meta.Window.rpc_register();
		Meta.WindowActor.rpc_register();
		Meta.Selection.rpc_register();
		Meta.SelectionSource.rpc_register();
		Meta.SelectionSourceMemory.rpc_register();
		Meta.ShapedTexture.rpc_register();
		Meta.Barrier.rpc_register();
		Meta.WaylandClient.rpc_register();
		Meta.AppLaunch.rpc_register();

		Clutter.Text.rpc_register();
		Clutter.ShaderEffect.rpc_register();
		Clutter.ClutterThreads.rpc_register();
		Clutter.Clutter.rpc_register();
		Clutter.Interval.rpc_register();
		Clutter.Constraint.rpc_register();
		Clutter.Actor.rpc_register();
		Clutter.LayoutManager.rpc_register();
		Clutter.ClutterPaintContext.rpc_register();
		Clutter.ClutterStage.rpc_register();
		OLLMrpc.Bin.TypeOverride.register(new Clutter.ClutterEventOverride());
		OLLMrpc.Bin.TypeOverride.register(new Clutter.ActorBoxOverride());
		OLLMrpc.Bin.TypeOverride.register(new Clutter.GraphenePointOverride());
		OLLMrpc.Bin.TypeOverride.register(new Clutter.InputDeviceOverride());
		OLLMrpc.Bin.TypeOverride.register(new Clutter.PickContextOverride());

		St.St.rpc_register();
		St.ThemeContext.rpc_register();
		St.Icon.rpc_register();
		St.IconTheme.rpc_register();
		St.ImageContent.rpc_register();
		St.FocusManager.rpc_register();

		Shell.GLSLEffect.rpc_register();
		Shell.BlurEffect.rpc_register();
		Shell.InvertLightnessEffect.rpc_register();
	}
}
