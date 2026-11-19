	[CCode (cname = "gsr_key_binding_enter")]
	private static extern void gsr_key_binding_enter(string name,
		uint modifiers, uint mask, bool builtin, bool reversed);

	[CCode (cname = "gsr_key_binding_leave")]
	private static extern void gsr_key_binding_leave();

	public bool keybindings_set_custom_handler(string name, Meta.KeyHandlerFunc handler)
	{
		var callback_id = Gsr.Client.Rpc.callback_bind((call) => {
			var display = (Display) Gsr.Client.Rpc.client.proxies.get(
				(int) call.args.get(0).get_uint64());
			Window? window = null;
			var win_h = (int) call.args.get(1).get_uint64();
			if (win_h != 0) {
				window = (Window) Gsr.Client.Rpc.client.proxies.get(win_h);
			}
			gsr_key_binding_enter(name, 0, 0, true, false);
			handler(display, window, null, KeyBinding());
			gsr_key_binding_leave();
			return null;
		});
		var response = Gsr.Client.Rpc.call_value(
			"Gsr-Mutter-Display.keybindings_set_custom_handler",
			null,
			OLLMrpc.args("st", name, callback_id));
		return response.retval.get_boolean();
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
		var response = Gsr.Client.Rpc.call_value(
			"Server-Bootstrap.get_display");
		display_singleton = (Display) response.retval.get_object();
		return display_singleton;
	}

	/**
	 * Alt+F2 {@code r}. Compositor stays up; {@code Server-Rpc-SpawnClient} replaces
	 * {@code gsr-client}. Does not call stock {@code meta_restart}.
	 *
	 * @param message text stock mutter would show; ignored here
	 * @param context stock {@link Context}; ignored here
	 */
	public void restart(string? message, Context context)
	{
		Gsr.Client.Rpc.call_value(
			"Server-Rpc-SpawnClient.restart",
			null,
			OLLMrpc.args("so", message, context));
	}

	/**
	 * True when this client was spawned by a manual restart.
	 *
	 * @return {@code client_is_restart} on {@link Gsr.Server.Rpc.SpawnClient}
	 */
	public bool is_restart()
	{
		var response = Gsr.Client.Rpc.call_value("Server-Rpc-SpawnClient.is_restart");
		return response.retval.get_boolean();
	}
