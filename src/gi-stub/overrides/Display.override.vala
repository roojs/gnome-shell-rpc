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
			return response.retval.get_uint();
		}

		public void request_pad_osd(Clutter.InputDevice pad, bool edition_mode)
		{
			uint64 device_lease = 0;
			var device_name = "";
			var lease = (uint64) pad.get_data<void*>("rpc-lid");
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
			var lease = (uint64) pad.get_data<void*>("rpc-lid");
			if (lease != 0) {
				device_lease = lease;
			} else {
				device_name = pad.get_device_name();
			}
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.get_pad_button_label", this,
				OLLMrpc.args("tsi", device_lease, device_name, button_number));
			return response.retval.get_string();
		}

		public string get_pad_feature_label(
			Clutter.InputDevice pad,
			PadFeatureType feature,
			PadDirection direction,
			int feature_number
		) {
			uint64 device_lease = 0;
			var device_name = "";
			var lease = (uint64) pad.get_data<void*>("rpc-lid");
			if (lease != 0) {
				device_lease = lease;
			} else {
				device_name = pad.get_device_name();
			}
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.get_pad_feature_label", this,
				OLLMrpc.args("tsiui", device_lease, device_name,
					(int) feature, (uint) direction, feature_number));
			return response.retval.get_string();
		}

		/**
		 * Stock {@code meta_display_get_startup_notification} is
		 * {@code introspectable="0"} — not in the typelib walk.
		 */
		public StartupNotification get_startup_notification()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Display.get_startup_notification", this);
			return (StartupNotification) response.retval.get_object();
		}

		/**
		 * Stock {@code meta_display_is_pointer_emulating_sequence}. Mutter-internal
		 * grab helper; gnome-shell JS never calls — always false out-of-process.
		 */
		public bool is_pointer_emulating_sequence(Clutter.EventSequence? sequence)
		{
			return false;
		}
