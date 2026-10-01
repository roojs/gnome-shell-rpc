		public static Settings get()
		{
			var response = Gsr.call_value(
				"St-Settings.get");
			return (Settings) response.retval.get_object();
		}
