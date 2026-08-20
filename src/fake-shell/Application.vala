namespace GnomeShellRpc.FakeShell
{
	/**
	 * Gtk application that connects {@link Remote.Session} and shows
	 * {@link TopBar}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * return new GnomeShellRpc.FakeShell.Application().run(argv);
	 * }}}
	 */
	public class Application : Gtk.Application
	{
		private Remote.Session session;

		public Application()
		{
			GLib.Object(
				application_id: "org.gnome.ShellRpc.FakeShell",
				flags: GLib.ApplicationFlags.DEFAULT_FLAGS
			);
		}

		public override void activate()
		{
			this.hold();
			this.session = new Remote.Session();
			this.session.connect.begin((obj, res) => {
				try {
					this.session.connect.end(res);
				} catch (GLib.Error e) {
					GLib.printerr("fake-shell: %s\n", e.message);
					this.release();
					this.quit();
					return;
				}
				var bar = new TopBar(this, this.session);
				bar.present();
				this.release();
			});
		}
	}
}
