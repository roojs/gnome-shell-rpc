		public uint add_keybinding(
			string name,
			GLib.Settings settings,
			KeyBindingFlags flags,
			KeyHandlerFunc handler
		) {
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				var display = (Display) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				Window? window = null;
				var win_h = (int) call.args.get(1).get_uint64();
				if (win_h != 0) {
					window = (Window) GnomeShellRpc.GiStub.Runtime.client.proxies.get(win_h);
				}
				handler(display, window, null, KeyBinding());
				return null;
			});
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.add_keybinding", this,
				OLLMrpc.args("ssut", name, settings.schema_id, (uint) flags, callback_id));
			return response.args.get(0).get_uint();
		}

		public void request_pad_osd(Clutter.InputDevice pad, bool edition_mode)
		{
			uint64 device_lease = 0;
			var device_name = "";
			var lease = (uint64) pad.get_data<void*>("gsr-lease-id");
			if (lease != 0) {
				device_lease = lease;
			} else {
				device_name = pad.get_device_name();
			}
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.request_pad_osd", this,
				OLLMrpc.args("tsb", device_lease, device_name, edition_mode));
		}

		public string get_pad_button_label(
			Clutter.InputDevice pad,
			int button_number
		) {
			uint64 device_lease = 0;
			var device_name = "";
			var lease = (uint64) pad.get_data<void*>("gsr-lease-id");
			if (lease != 0) {
				device_lease = lease;
			} else {
				device_name = pad.get_device_name();
			}
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.get_pad_button_label", this,
				OLLMrpc.args("tsi", device_lease, device_name, button_number));
			return response.args.get(0).get_string();
		}

		public string get_pad_feature_label(
			Clutter.InputDevice pad,
			PadFeatureType feature,
			PadDirection direction,
			int feature_number
		) {
			uint64 device_lease = 0;
			var device_name = "";
			var lease = (uint64) pad.get_data<void*>("gsr-lease-id");
			if (lease != 0) {
				device_lease = lease;
			} else {
				device_name = pad.get_device_name();
			}
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.get_pad_feature_label", this,
				OLLMrpc.args("tsiui", device_lease, device_name,
					(int) feature, (uint) direction, feature_number));
			return response.args.get(0).get_string();
		}

		public StartupNotification get_startup_notification()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Display.get_startup_notification", this);
			return (StartupNotification) response.result.get(0);
		}

		/**
		 * Lease handle in {@code args[0]} — Ui.Display packs uint64, not
		 * {@code result} (live GObject rows arrive with handle 0).
		 */
		public Context get_context()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Display.get_context", this);
			var ctx = new Context();
			if (response.args.size > 0) {
				ctx.set_data_full(
					"gsr-lease-id",
					(void*) response.args.get(0).get_uint64(),
					null
				);
			}
			return ctx;
		}

		/**
		 * Lease handle in {@code args[0]} — same packing as {@link get_context}.
		 */
		public Compositor get_compositor()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Display.get_compositor", this);
			var compositor = new Compositor();
			if (response.args.size > 0) {
				compositor.set_data_full(
					"gsr-lease-id",
					(void*) response.args.get(0).get_uint64(),
					null
				);
			}
			return compositor;
		}

		/**
		 * Stock {@code meta_display_is_pointer_emulating_sequence}. Mutter-internal
		 * grab helper; gnome-shell JS never calls — always false out-of-process.
		 */
		public bool is_pointer_emulating_sequence(Clutter.EventSequence? sequence)
		{
			return false;
		}
