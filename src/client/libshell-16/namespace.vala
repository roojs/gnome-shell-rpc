namespace Shell
{
	[CCode (cname = "gsr_client_shell_register")]
	public void register()
	{
		ClutterEventOverride.register();
		InputDeviceOverride.register();
		PickContextOverride.register();
		KeyBindingOverride.register();
		BarrierEventOverride.register();
		RegionOverride.register();
		Gsr.Boxed.register_Clutter_boxed_types();
		Gsr.Boxed.register_St_boxed_types();
	}
}
