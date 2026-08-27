		public void terminate_with_error(GLib.Error error)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Context.terminate_with_error",
				this,
				OLLMrpc.args(
					"sis",
					error.domain.to_string(),
					error.code,
					error.message
				)
			);
		}
