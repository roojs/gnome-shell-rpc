		/**
		 * {@code GLib.File} is not D-Bus-marshallable — send URI; mock/live
		 * resolve. GIR {@code get_default} is static (generator Pattern F).
		 */
		public BackgroundImage load(GLib.File file)
		{
			var uri = file != null ? file.get_uri() : "";
			var response = GnomeShellRpc.call_value(
				"Meta-BackgroundImageCache.load",
				this,
				OLLMrpc.args("s", uri)
			);
			return (BackgroundImage) response.retval.get_object();
		}
