namespace GnomeShellRpc.GiRpcMock
{
	/**
	 * Singleton boot object graph for Meta → Clutter stage chain.
	 */
	public class MockBootGraph : GLib.Object
	{
		private static MockBootGraph? _instance;

		public const int SCREEN_WIDTH = 1920;
		public const int SCREEN_HEIGHT = 1080;

		public GLib.Object display { get; private set; }
		public GLib.Object context { get; private set; }
		public GLib.Object compositor { get; private set; }
		public GLib.Object backend { get; private set; }
		public GLib.Object stage { get; private set; }
		public GLib.Object st_settings { get; private set; }
		public GLib.Object startup_notification { get; private set; }
		public GLib.Object workspace_manager { get; private set; }
		public GLib.Object workspace { get; private set; }
		public GLib.Object window_group { get; private set; }
		public GLib.Object top_window_group { get; private set; }
		public GLib.Object feedback_group { get; private set; }
		public GLib.Object monitor_manager { get; private set; }
		public GLib.Object theme_context { get; private set; }
		public GLib.Object focus_manager { get; private set; }
		public GLib.Object laters { get; private set; }
		public GLib.Object background_image_cache { get; private set; }

		private MockBootGraph()
		{
			this.display = HelperMock.mint("Meta-Display");
			this.context = HelperMock.mint("Meta-Context");
			this.compositor = HelperMock.mint("Meta-Compositor");
			this.backend = HelperMock.mint("Meta-Backend");
			this.stage = HelperMock.mint("Clutter-Stage");
			this.st_settings = HelperMock.mint("St-Settings");
			this.startup_notification = HelperMock.mint("Meta-StartupNotification");
			this.workspace_manager = HelperMock.mint("Meta-WorkspaceManager");
			this.workspace = HelperMock.mint("Meta-Workspace");
			this.window_group = HelperMock.mint("Clutter-Actor");
			this.top_window_group = HelperMock.mint("Clutter-Actor");
			this.feedback_group = HelperMock.mint("Clutter-Actor");
			this.monitor_manager = HelperMock.mint("Meta-MonitorManager");
			this.theme_context = HelperMock.mint("St-ThemeContext");
			this.focus_manager = HelperMock.mint("St-FocusManager");
			this.laters = HelperMock.mint("Meta-Laters");
			this.background_image_cache = HelperMock.mint("Meta-BackgroundImageCache");
		}

		public static MockBootGraph get()
		{
			if (_instance == null) {
				_instance = new MockBootGraph();
			}
			return _instance;
		}
	}
}
