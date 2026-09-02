		public FocusManager get_for_stage(Clutter.Stage stage)
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"St-FocusManager.get_for_stage", null,
				OLLMrpc.args("o", stage));
			return (FocusManager) response.retval.get_object();
		}
