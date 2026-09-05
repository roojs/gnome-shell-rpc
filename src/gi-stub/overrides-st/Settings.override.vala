		public static Settings get()
		{
			var response = GnomeShellRpc.call_value(
				"St-Settings.get", null);
			return (Settings) response.retval.get_object();
		}
