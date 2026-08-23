namespace Meta
{
	/**
	 * Client stub for {@code MetaStartupNotification}.
	 *
	 * Stock: {@code meta_startup_notification_create_launcher}.
	 */
	public class StartupNotification : GLib.Object
	{
		/**
		 * Create an app launch context for {@link Gio.AppInfo.launch}.
		 *
		 * @return {@link LaunchContext} (a {@link Gio.AppLaunchContext})
		 */
		public LaunchContext create_launcher()
		{
			return new LaunchContext();
		}
	}
}
