		public void set_file(Gio.File file, GDesktopEnums.BackgroundStyle style) {
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Meta-Helper-Background.set_file",
				this,
				OLLMrpc.args(
					"si",
					file != null ? file.get_uri() : "",
					(int) style
				)
			);
		}
