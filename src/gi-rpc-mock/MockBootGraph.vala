namespace GnomeShellRpc.GiRpcMock
{
	/**
	 * Singleton boot object graph for Meta → Clutter stage chain.
	 */
	public class MockBootGraph : GLib.Object
	{
		private static MockBootGraph? _instance;

		public GLib.Object display { get; private set; }
		public GLib.Object context { get; private set; }
		public GLib.Object compositor { get; private set; }
		public GLib.Object backend { get; private set; }
		public GLib.Object stage { get; private set; }

		private MockBootGraph()
		{
			this.display = HelperMock.mint("Meta-Display");
			this.context = HelperMock.mint("Meta-Context");
			this.compositor = HelperMock.mint("Meta-Compositor");
			this.backend = HelperMock.mint("Meta-Backend");
			this.stage = HelperMock.mint("Clutter-Stage");
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
