namespace Gsr.Server.Meta
{
	/* G_DEFINE_TYPE registers this class on the first get_type call.
	 * Gi.register maps MetaWindow only. Nested clients are MetaWindowWayland. */
	[CCode (cname = "meta_window_wayland_get_type")]
	extern GLib.Type meta_window_wayland_get_type();

	public void rpc_register(StartupFrameLock gate)
	{
		SoundPlayer.rpc_register();
		Background.rpc_register();
		BackgroundImageCache.rpc_register();
		BackgroundActor.rpc_register();
		Context.rpc_register(gate);
		Settings.rpc_register();
		IdleMonitor.rpc_register();
		Keybinding.rpc_register();
		Window.rpc_register();
		WindowActor.rpc_register();
		Selection.rpc_register();
		SelectionSource.rpc_register();
		SelectionSourceMemory.rpc_register();
		ShapedTexture.rpc_register();
		Barrier.rpc_register();
		OLLMrpc.Bin.TypeOverride.register(new BarrierEventOverride());
		OLLMrpc.Bin.TypeOverride.register(new KeyBindingOverride());
		WaylandClient.rpc_register();
		AppLaunch.rpc_register();
		/* Display and Compositor stay before Gi.register in Server.start. */
		// Display.rpc_register();
		// Compositor.rpc_register();
	}

	public void bind(global::Meta.Display display)
	{
		Settings.bind(display);
		AppLaunch.bind(display);
	}

	public void register_alias(global::Meta.Display display, Display ui)
	{
		OLLMrpc.Request.register_live("Meta-Display", ui);
		OLLMrpc.Request.register_live("Meta-Compositor",
			new Compositor(display.get_compositor()));
		OLLMrpc.Bin.register_alias("Meta-Compositor", display.get_compositor().get_type());
		OLLMrpc.Bin.register_alias("Meta-Context", display.get_context().get_type());
		OLLMrpc.Bin.register_alias("Meta-Backend",
			display.get_context().get_backend().get_type());
		OLLMrpc.Bin.register_alias("Meta-Window", meta_window_wayland_get_type());
	}
}
