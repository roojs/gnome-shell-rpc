namespace Shell
{
	[CCode (cname = "gsr_client_shell_register")]
	public void register()
	{
		ClutterEventOverride.register();
		ActorBoxOverride.register();
		GraphenePointOverride.register();
		InputDeviceOverride.register();
		PickContextOverride.register();
	}
}
