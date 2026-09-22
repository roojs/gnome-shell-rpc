		public static FocusManager get_for_stage(Clutter.Stage stage)
		{
			var response = GnomeShellRpc.call_value(
				"St-FocusManager.get_for_stage",
				null,
				OLLMrpc.args("o", stage));
			return (FocusManager) response.retval.get_object();
		}

		/**
		 * Stock {@code st_focus_manager_navigate_from_event} — KEY_PRESS only
		 * on the compositor; pack type / keyval / state ({@code iuu}).
		 */
		public bool navigate_from_event(Clutter.Event event)
		{
			var response = GnomeShellRpc.call_value(
				"Helper-FocusManager.navigate_from_event", this,
				OLLMrpc.args("iuu",
					(int) event.type(),
					event.get_key_symbol(),
					(uint) event.get_state()));
			return response.retval.get_boolean();
		}
