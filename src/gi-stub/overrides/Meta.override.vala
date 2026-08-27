	public bool keybindings_set_custom_handler(string name, KeyHandlerFunc handler)
	{
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
			"Helper-Display.keybindings_set_custom_handler", null,
			OLLMrpc.args("st", name, callback_id));
		return response.args.get(0).get_boolean();
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
		if (display_singleton != null) {
			return display_singleton;
		}
		display_singleton = new Display();
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"RPC-Bootstrap.get_display");
		if (response.args.size > 0) {
			display_singleton.set_data(
				"gsr-lease-id",
				response.args.get(0).get_uint64().to_string()
			);
		}
		return display_singleton;
	}
