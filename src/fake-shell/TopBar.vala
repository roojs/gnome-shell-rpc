namespace GnomeShellRpc.FakeShell
{
	/**
	 * Throwaway top bar: clock, focused title, Minimize.
	 *
	 * Ordinary {@link Gtk.ApplicationWindow} (layer-shell is an open 0.3 question).
	 *
	 * == Example ==
	 *
	 * {{{
	 * var bar = new GnomeShellRpc.FakeShell.TopBar(app, session);
	 * bar.present();
	 * }}}
	 */
	public class TopBar : Gtk.ApplicationWindow
	{
		public TopBar(Gtk.Application app, Remote.Session session)
		{
			GLib.Object(application: app, title: "fake-shell");
			this.set_default_size(640, 40);

			var clock = new Gtk.Label("");
			var title = new Gtk.Label("");
			var button = new Gtk.Button.with_label("Minimize");
			var gedit = new Gtk.Button.with_label("gedit");
			button.clicked.connect(() => {
				if (session.display.focused_window.id == 0) {
					return;
				}
				session.display.focused_window.minimize.begin((obj, res) => {
					try {
						session.display.focused_window.minimize.end(res);
					} catch (GLib.Error e) {
						GLib.warning("%s", e.message);
					}
				});
			});
			gedit.clicked.connect(() => {
				try {
					GLib.Process.spawn_async(
						null,
						{ "gedit" },
						null,
						GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.DO_NOT_REAP_CHILD,
						null,
						null
					);
				} catch (GLib.Error e) {
					GLib.warning("%s", e.message);
				}
			});

			var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
			box.append(clock);
			box.append(title);
			box.append(button);
			box.append(gedit);
			this.set_child(box);

			clock.label = (new GLib.DateTime.now_local()).format("%H:%M:%S");
			title.label = session.display.focused_window.title;
			GLib.Timeout.add_seconds(1, () => {
				clock.label = (new GLib.DateTime.now_local()).format("%H:%M:%S");
				title.label = session.display.focused_window.title;
				return GLib.Source.CONTINUE;
			});
		}
	}
}
