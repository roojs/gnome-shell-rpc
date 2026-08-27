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

		/**
		 * Sound player for this display (stock {@code meta_display_get_sound_player}).
		 */
		public SoundPlayer get_sound_player()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Display.get_sound_player", this);
			var player = new SoundPlayer();
			player.set_data(
				"gsr-lease-id",
				response.args.get(0).get_uint64().to_string()
			);
			return player;
		}

		/**
		 * Stock {@code meta_display_add_keybinding}. {@link GLib.Settings}
		 * crosses as schema id.
		 */
		public uint add_keybinding(
			string name,
			GLib.Settings settings,
			KeyBindingFlags flags,
			KeyHandlerFunc callback
		) {
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				var display = (Display) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				Window? window = null;
				var win_h = (int) call.args.get(1).get_uint64();
				if (win_h != 0) {
					window = (Window) GnomeShellRpc.GiStub.Runtime.client.proxies.get(win_h);
				}
				callback(display, window);
				return null;
			});
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.add_keybinding", this,
				OLLMrpc.args("ssut", name, settings.schema_id, (uint) flags, callback_id));
			return response.args.get(0).get_uint();
		}

		/**
		 * Stock {@code meta_display_request_pad_osd}.
		 */
		public void request_pad_osd(Clutter.InputDevice pad, bool edition_mode)
		{
			uint64 device_lease = 0;
			var device_name = "";
			var lease = pad.get_data<string>("gsr-lease-id");
			if (lease != null && lease.length > 0) {
				device_lease = uint64.parse(lease);
			} else {
				device_name = pad.get_device_name();
			}
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.request_pad_osd", this,
				OLLMrpc.args("tsb", device_lease, device_name, edition_mode));
		}

		/**
		 * Stock {@code meta_display_get_pad_button_label}.
		 */
		public string get_pad_button_label(
			Clutter.InputDevice pad,
			int button_number
		) {
			uint64 device_lease = 0;
			var device_name = "";
			var lease = pad.get_data<string>("gsr-lease-id");
			if (lease != null && lease.length > 0) {
				device_lease = uint64.parse(lease);
			} else {
				device_name = pad.get_device_name();
			}
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.get_pad_button_label", this,
				OLLMrpc.args("tsi", device_lease, device_name, button_number));
			return response.args.get(0).get_string();
		}

		/**
		 * Stock {@code meta_display_get_pad_feature_label}.
		 */
		public string get_pad_feature_label(
			Clutter.InputDevice pad,
			PadFeatureType feature,
			PadDirection direction,
			int feature_number
		) {
			uint64 device_lease = 0;
			var device_name = "";
			var lease = pad.get_data<string>("gsr-lease-id");
			if (lease != null && lease.length > 0) {
				device_lease = uint64.parse(lease);
			} else {
				device_name = pad.get_device_name();
			}
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.get_pad_feature_label", this,
				OLLMrpc.args("tsiui", device_lease, device_name,
					(int) feature, (uint) direction, feature_number));
			return response.args.get(0).get_string();
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
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"RPC-Bootstrap.get_display"
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

	/**
	 * Stock {@code meta_keybindings_set_custom_handler}.
	 */
	public bool keybindings_set_custom_handler(string name, KeyHandlerFunc callback)
	{
		var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			var display = (Display) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
				(int) call.args.get(0).get_uint64());
			Window? window = null;
			var win_h = (int) call.args.get(1).get_uint64();
			if (win_h != 0) {
				window = (Window) GnomeShellRpc.GiStub.Runtime.client.proxies.get(win_h);
			}
			callback(display, window);
			return null;
		});
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"Helper-Display.keybindings_set_custom_handler", null,
			OLLMrpc.args("st", name, callback_id));
		return response.args.get(0).get_boolean();
	}

	/**
	 * Watch func for {@link Display.add_keybinding} (mutter Vala drops
	 * GIR user_data). Event / KeyBinding packing is 0.5.3 leftover.
	 */
	public delegate void KeyHandlerFunc(Display display, Window? window);

	[Flags]
	public enum KeyBindingFlags {
		NONE = 0,
		PER_WINDOW = 1,
		BUILTIN = 2,
		IS_REVERSED = 4,
		NON_MASKABLE = 8,
		IGNORE_AUTOREPEAT = 16,
		TRIGGER_RELEASE = 32
	}

	public enum PadFeatureType {
		RING = 0,
		STRIP = 1
	}

	public enum PadDirection {
		UP = 0,
		DOWN = 1,
		CW = 2,
		CCW = 3
	}
}
