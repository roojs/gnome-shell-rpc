		public static FocusManager get_for_stage(Clutter.Stage stage)
		{
			var response = GnomeShellRpc.call_value(
				"St-FocusManager.get_for_stage", null,
				OLLMrpc.args("o", stage));
			return (FocusManager) response.retval.get_object();
		}
