namespace Gsr.Server.Clutter
{
	/* G_DEFINE_TYPE registers this class on the first get_type call.
	 * Gi.register maps ClutterStageView only. Nested views are MetaRendererView. */
	[CCode (cname = "meta_renderer_view_get_type")]
	extern GLib.Type meta_renderer_view_get_type();

	public void rpc_register()
	{
		Text.rpc_register();
		ShaderEffect.rpc_register();
		ClutterThreads.rpc_register();
		Clutter.rpc_register();
		Interval.rpc_register();
		Constraint.rpc_register();
		Actor.rpc_register();
		LayoutManager.rpc_register();
		ClutterPaintContext.rpc_register();
		ClutterStage.rpc_register();
		OLLMrpc.Bin.TypeOverride.register(new ClutterEventOverride());
		OLLMrpc.Bin.TypeOverride.register(new ActorBoxOverride());
		OLLMrpc.Bin.TypeOverride.register(new GraphenePointOverride());
		OLLMrpc.Bin.TypeOverride.register(new InputDeviceOverride());
		OLLMrpc.Bin.TypeOverride.register(new PickContextOverride());
		/* Clutter-Frame stays immediately after Gi.register in Server.start. */
		// OLLMrpc.Bin.register("Clutter-Frame", typeof(global::Clutter.Frame));
		OLLMrpc.Bin.register_alias("Clutter-Constraint", typeof(Constraint));
		OLLMrpc.Bin.register_alias("Clutter-LayoutManager", typeof(LayoutManager));
	}

	public void register_alias(global::Clutter.Actor stage)
	{
		/* --wayland --nested is the X11 nested backend.
		 * Clutter-Stage runs here: the stage is MetaStageX11.
		 * Native already stored MetaStage as Meta-Stage and skips.
		 * Clutter backend and seat are subclasses on this nested boot too.
		 * They are not native-only. */
		var ctx = stage.get_context();
		var clutter_backend = ctx.get_backend();
		var seat = clutter_backend.get_default_seat();
		if (!OLLMrpc.Bin.gtype_to_alias.has_key(stage.get_type())) {
			OLLMrpc.Bin.register_alias("Clutter-Stage", stage.get_type());
		}
		OLLMrpc.Bin.register_alias("Clutter-StageView", meta_renderer_view_get_type());
		if (!OLLMrpc.Bin.gtype_to_alias.has_key(ctx.get_type())) {
			OLLMrpc.Bin.register_alias("Clutter-Context", ctx.get_type());
		}
		if (!OLLMrpc.Bin.gtype_to_alias.has_key(clutter_backend.get_type())) {
			OLLMrpc.Bin.register_alias("Clutter-Backend", clutter_backend.get_type());
		}
		if (!OLLMrpc.Bin.gtype_to_alias.has_key(seat.get_type())) {
			OLLMrpc.Bin.register_alias("Clutter-Seat", seat.get_type());
		}
	}
}
