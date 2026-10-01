namespace Gsr.Server.Shell
{
	public void rpc_register()
	{
		GLSLEffect.rpc_register();
		BlurEffect.rpc_register();
		InvertLightnessEffect.rpc_register();
	}

	public void bind(global::Meta.Display display)
	{
		GLSLEffect.bind(display);
		BlurEffect.bind(display);
		InvertLightnessEffect.bind(display);
	}
}
