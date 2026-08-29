/**
 * Hand Meta GI stubs for {@code meta-smoke.js} (plan 0.5 vertical slice).
 *
 * Tiny client-side {@link Display} / {@link Window} that RPC to the nested
 * plugin via {@link GnomeShellRpc.GiStub.Runtime}. Not generated — the
 * pattern here feeds {@code GenClient} later.
 *
 * == Example ==
 *
 * {{{
 * var display = Meta.get_display();
 * var win = display.get_focus_window();
 * win.minimize();
 * }}}
 */
namespace Meta
{
	/**
	 * Register wire aliases for the mini Meta stubs (mirrors generated
	 * {@code Meta.register()} from gi-stub-gen).
	 */
	public void register()
	{
		Window.register();
		WindowActor.register();
		Display.register();
		Context.register();
		Compositor.register();
		Backend.register();
	}
}
