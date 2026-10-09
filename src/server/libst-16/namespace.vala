namespace Gsr.Server.St
{
	public void rpc_register()
	{
		St.rpc_register();
		ThemeContext.rpc_register();
		Icon.rpc_register();
		IconTheme.rpc_register();
		ImageContent.rpc_register();
		DrawingAreaActor.rpc_register();
		DrawingArea.rpc_register();
		FocusManager.rpc_register();
		OLLMrpc.Bin.register_alias("St-Widget", typeof(Clutter.Actor));
		register_boxed_types();
	}
}
