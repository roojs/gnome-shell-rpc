namespace Meta
{
	/**
	 * Client stub for the compositor display.
	 *
	 * Real Meta methods only (plus {@link get_display} bootstrap). Fetches
	 * window snapshots over {@code Meta-Display.*}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * var display = Meta.get_display();
	 * var launcher = display.get_startup_notification().create_launcher();
	 * }}}
	 */
	public class Display : GLib.Object
	{
		private StartupNotification startup_notification =
			new StartupNotification();

		/**
		 * All windows currently known to the plugin.
		 *
		 * @return list of {@link Window} stubs (may be empty)
		 */
		public GLib.List<Window> list_all_windows()
		{
			var rows = GnomeShellRpc.GiStub.Runtime.call_list(
				"Meta-Display.list_windows",
				new GnomeShellRpc.Ui.DisplayParams(),
				typeof(GnomeShellRpc.Ui.Window)
			);
			var list = new GLib.List<Window>();
			foreach (unowned GLib.Object row in rows) {
				var snap = (GnomeShellRpc.Ui.Window)row;
				var win = new Window() {
					title = snap.title,
					wm_class = snap.wm_class,
				};
				win.set_data("gsr-lease-id", snap.id.to_string());
				list.append(win);
			}
			return list;
		}

		/**
		 * Focused window, if any.
		 *
		 * @return stub {@link Window}, or {@code null}
		 */
		public Window? get_focus_window()
		{
			var snap = (GnomeShellRpc.Ui.Window?) GnomeShellRpc.GiStub.Runtime.call_object(
				"Meta-Display.get_focused_window",
				new GnomeShellRpc.Ui.DisplayParams(),
				typeof(GnomeShellRpc.Ui.Window)
			);
			if (snap == null) {
				return null;
			}
			var win = new Window() {
				title = snap.title,
				wm_class = snap.wm_class,
			};
			win.set_data("gsr-lease-id", snap.id.to_string());
			return win;
		}

		/**
		 * Startup-notification helper (stock {@code meta_display_get_startup_notification}).
		 */
		public unowned StartupNotification get_startup_notification()
		{
			return this.startup_notification;
		}

		/**
		 * Compositor for this display (requires bootstrap display lease).
		 */
		public Compositor get_compositor()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Display.get_compositor", this);
			var compositor = new Compositor();
			compositor.set_data(
				"gsr-lease-id",
				response.args.get(0).get_uint64().to_string()
			);
			return compositor;
		}
	}

	private static Display? display_singleton = null;

	/**
	 * Bootstrap: return a display stub (RPC connects on first call).
	 *
	 * Not a stock Meta API — out-of-process stand-in for {@code global.display}.
	 *
	 * @return {@link Display} stub
	 */
	public Display get_display()
	{
		if (display_singleton == null) {
			display_singleton = new Display();
			OLLMrpc.CallParam bootstrap = new GnomeShellRpc.Rpc.BootstrapParams();
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"RPC-Bootstrap.get_display",
				null,
				null,
				bootstrap
			);
			if (response.args.size > 0) {
				display_singleton.set_data(
					"gsr-lease-id",
					response.args.get(0).get_uint64().to_string()
				);
			}
		}
		return display_singleton;
	}
}
