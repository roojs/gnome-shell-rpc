		public static Settings get()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"St-Settings.get", null);
			return (Settings) response.retval.get_object();
		}
