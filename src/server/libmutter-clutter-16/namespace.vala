namespace Gsr.Server.Clutter
{
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
		OLLMrpc.Bin.register("Clutter-Frame", typeof(global::Clutter.Frame));
	}

	public void bind(global::Meta.Display display)
	{
		/* Gi convert needs gtype_to_alias. Align/Bind/Snap stay real mutter types. */
		OLLMrpc.Bin.register_alias("Clutter-Constraint", typeof(Constraint));
		OLLMrpc.Bin.register_alias("St-Widget", typeof(Actor));
		OLLMrpc.Bin.register_alias("Clutter-LayoutManager", typeof(LayoutManager));

		var stage = display.get_context().get_backend().get_stage();
		var ctx = stage != null ? stage.get_context() : null;
		var clutter_backend = ctx != null ? ctx.get_backend() : null;
		var seat = clutter_backend != null ? clutter_backend.get_default_seat() : null;
		if (stage != null && !OLLMrpc.Bin.gtype_to_alias.has_key(stage.get_type())) {
			OLLMrpc.Bin.register_alias("Clutter-Stage", stage.get_type());
		}
		if (ctx != null && !OLLMrpc.Bin.gtype_to_alias.has_key(ctx.get_type())) {
			OLLMrpc.Bin.register_alias("Clutter-Context", ctx.get_type());
		}
		if (clutter_backend != null
				&& !OLLMrpc.Bin.gtype_to_alias.has_key(clutter_backend.get_type())) {
			OLLMrpc.Bin.register_alias("Clutter-Backend", clutter_backend.get_type());
		}
		if (seat != null && !OLLMrpc.Bin.gtype_to_alias.has_key(seat.get_type())) {
			OLLMrpc.Bin.register_alias("Clutter-Seat", seat.get_type());
		}
	}
}
