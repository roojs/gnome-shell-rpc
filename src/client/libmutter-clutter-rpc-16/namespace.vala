namespace Gsr.Client.Clutter
{
	public void register()
	{
		global::Clutter.register();
		/*
		 * Size-0 record, so generation does not emit register().
		 * Clutter.register() only calls that on generated classes.
		 * opaque-as-class would make Frame a GObject; before-update
		 * fills a boxed ClutterFrame. typeof needs an instance first.
		 */
		var frame = new global::Clutter.Frame();
		OLLMrpc.Bin.register("Clutter-Frame", typeof(global::Clutter.Frame));
		frame = null;
	}
}
