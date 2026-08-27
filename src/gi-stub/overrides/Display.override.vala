		public uint add_keybinding(string name, GLib.Settings settings,
			KeyBindingFlags flags, KeyHandlerFunc handler) {
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				var display = (Display) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				Window? window = null;
				var win_h = (int) call.args.get(1).get_uint64();
				if (win_h != 0) {
					window = (Window) GnomeShellRpc.GiStub.Runtime.client.proxies.get(win_h);
				}
				handler(display, window, null, null, null);
			});
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Display.add_keybinding", this,
				OLLMrpc.args("ssut", name, settings.schema_id, (uint) flags, callback_id));
			return response.args.get(0).get_uint();
		}
