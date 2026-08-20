namespace GnomeShellRpc.Remote
{
	/**
	 * Proxy for one leased compositor window handle.
	 *
	 * == Example ==
	 *
	 * {{{
	 * yield session.display.focused_window.minimize();
	 * }}}
	 */
	public class Window : GLib.Object
	{
		public int id { get; construct; }
		public Session session { get; construct; }
		public string title { get; set; default = ""; }
		public string wm_class { get; set; default = ""; }
		public bool minimized { get; set; default = false; }
		public bool maximized { get; set; default = false; }
		public Shared.Rectangle frame_rect { get; set; default = new Shared.Rectangle(); }

		public signal void closed();

		public Window(Session session, int id)
		{
			GLib.Object(session: session, id: id);
		}

		public async void minimize() throws GLib.Error
		{
			yield this.session.display.minimize_window(this.id);
		}

		public async void unminimize() throws GLib.Error
		{
			yield this.session.display.unminimize_window(this.id);
		}

		public async void activate() throws GLib.Error
		{
			yield this.session.display.activate_window(this.id);
		}

		public async void close() throws GLib.Error
		{
			yield this.session.display.close_window(this.id);
		}
	}
}
