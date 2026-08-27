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
				handler(display, window, null, null, null);
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
