namespace Gsr.Server.Meta
{
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
		WaylandClient.rpc_register();
		AppLaunch.rpc_register();
		Display.rpc_register();
		Compositor.rpc_register();
	}

	public Display bind(global::Meta.Display display)
	{
		Settings.bind(display);
		AppLaunch.bind(display);

		var ui = new Display(display);
		OLLMrpc.Request.register_live("Meta-Display", ui);
		var compositor = display.get_compositor();
		OLLMrpc.Request.register_live("Meta-Compositor", new Compositor(compositor));
		OLLMrpc.Bin.register_alias("Meta-Compositor", compositor.get_type());
		OLLMrpc.Bin.register_alias("Meta-Context", display.get_context().get_type());
		var backend = display.get_context().get_backend();
		OLLMrpc.Bin.register_alias("Meta-Backend", backend.get_type());
		var monitor_manager = backend.get_monitor_manager();
		if (monitor_manager != null
				&& !OLLMrpc.Bin.gtype_to_alias.has_key(monitor_manager.get_type())) {
			OLLMrpc.Bin.register_alias("Meta-MonitorManager", monitor_manager.get_type());
		}
		var sn = display.get_startup_notification();
		if (sn != null && !OLLMrpc.Bin.gtype_to_alias.has_key(sn.get_type())) {
			OLLMrpc.Bin.register_alias("Meta-StartupNotification", sn.get_type());
		}
		var player = display.get_sound_player();
		if (player != null && !OLLMrpc.Bin.gtype_to_alias.has_key(player.get_type())) {
			OLLMrpc.Bin.register_alias("Meta-SoundPlayer", player.get_type());
		}
		var idle = backend.get_core_idle_monitor();
		if (idle != null && !OLLMrpc.Bin.gtype_to_alias.has_key(idle.get_type())) {
			OLLMrpc.Bin.register_alias("Meta-IdleMonitor", idle.get_type());
		}
		/* Gi.register maps MetaWindow only. Nested clients are
		 * MetaWindowWayland (--no-x11). from_name does not load it. */
		var wayland_window = meta_window_wayland_get_type();
		if (!OLLMrpc.Bin.gtype_to_alias.has_key(wayland_window)) {
			OLLMrpc.Bin.register_alias("Meta-Window", wayland_window);
		}
		return ui;
	}
}
