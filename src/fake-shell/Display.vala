namespace GnomeShellRpc.FakeShell
{
	/**
	 * Client-side display: window graph plus {@code Display} calls.
	 *
	 * == Example ==
	 *
	 * {{{
	 * yield session.display.list_windows();
	 * yield session.display.focused_window.minimize();
	 * }}}
	 */
	public class Display : GLib.Object
	{
		public Session session { get; construct; }
		public Gee.HashMap<int, Window> windows { get; set; default = new Gee.HashMap<int, Window>(); }
		public Window focused_window { get; private set; }

		public Display(Session session)
		{
			GLib.Object(session: session);
			this.focused_window = new Window(session, 0);
		}

		public async void list_windows() throws GLib.Error
		{
			var list_resp = yield this.session.call(new OLLMrpc.Request() {
				method = "Meta-Display.list_windows",
				param = new Ui.DisplayParams(),
			});
			var seen = new Gee.HashSet<int>();
			foreach (var obj in list_resp.result) {
				var snap = (Ui.Window)obj;
				seen.add(snap.id);
				if (!this.windows.has_key(snap.id)) {
					this.windows.set(snap.id, new Window(this.session, snap.id));
					this.session.client.proxies.set(snap.id, this.windows.get(snap.id));
				}
				var win = this.windows.get(snap.id);
				win.title = snap.title;
				win.wm_class = snap.wm_class;
				win.minimized = snap.minimized;
				win.maximized = snap.maximized;
				win.frame_rect = snap.frame_rect;
			}
			var stale = new Gee.ArrayList<int>();
			foreach (var id in this.windows.keys) {
				if (seen.contains(id)) {
					continue;
				}
				stale.add(id);
			}
			foreach (var id in stale) {
				var gone = this.windows.get(id);
				this.windows.unset(id);
				this.session.client.proxies.unset(id);
				gone.closed();
			}
			yield this.update_focus();
		}

		/**
		 * Fetch the focused window snapshot ({@code Meta-Display.get_focused_window}).
		 *
		 * Named {@link update_focus} so it does not clash with the
		 * {@link focused_window} property C getter.
		 */
		public async void update_focus() throws GLib.Error
		{
			var resp = yield this.session.call(new OLLMrpc.Request() {
				method = "Meta-Display.get_focused_window",
				param = new Ui.DisplayParams(),
			});
			if (resp.result.size == 0) {
				if (this.focused_window.id != 0) {
					this.focused_window = new Window(this.session, 0);
				}
				return;
			}
			var snap = (Ui.Window)resp.result.get(0);
			if (!this.windows.has_key(snap.id)) {
				this.windows.set(snap.id, new Window(this.session, snap.id));
				this.session.client.proxies.set(snap.id, this.windows.get(snap.id));
			}
			var win = this.windows.get(snap.id);
			win.title = snap.title;
			win.wm_class = snap.wm_class;
			win.minimized = snap.minimized;
			win.maximized = snap.maximized;
			win.frame_rect = snap.frame_rect;
			this.focused_window = win;
		}

		public async void minimize_window(int object_id) throws GLib.Error
		{
			yield this.session.call(new OLLMrpc.Request() {
				method = "Meta-Display.minimize_window",
				param = new Ui.WindowParams() {
					object_id = object_id,
				},
			});
		}

		public async void unminimize_window(int object_id) throws GLib.Error
		{
			yield this.session.call(new OLLMrpc.Request() {
				method = "Meta-Display.unminimize_window",
				param = new Ui.WindowParams() {
					object_id = object_id,
				},
			});
		}

		public async void activate_window(int object_id) throws GLib.Error
		{
			yield this.session.call(new OLLMrpc.Request() {
				method = "Meta-Display.activate_window",
				param = new Ui.WindowParams() {
					object_id = object_id,
				},
			});
		}

		public async void close_window(int object_id) throws GLib.Error
		{
			yield this.session.call(new OLLMrpc.Request() {
				method = "Meta-Display.close_window",
				param = new Ui.WindowParams() {
					object_id = object_id,
				},
			});
		}
	}
}
