		public ThemeContext get_for_stage(Clutter.Stage stage)
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"St-ThemeContext.get_for_stage", null,
				OLLMrpc.args("o", stage));
			return (ThemeContext) response.retval.get_object();
		}
