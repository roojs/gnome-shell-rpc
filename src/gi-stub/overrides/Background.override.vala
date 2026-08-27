		public void set_file(GLib.File file, GDesktop.BackgroundStyle style)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Background.set_file",
				this,
				OLLMrpc.args(
					"si",
					file != null ? file.get_uri() : "",
					(int) style
				)
			);
		}
