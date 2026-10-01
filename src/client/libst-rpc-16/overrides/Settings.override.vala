		public static Settings get()
		{
			var response = Gsr.Client.Rpc.call_value(
				"St-Settings.get");
			return (Settings) response.retval.get_object();
		}
