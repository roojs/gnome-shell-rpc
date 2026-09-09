		public GLib.File application_stylesheet { get; construct; }
		public GLib.File theme_stylesheet { get; construct; }
		public GLib.File default_stylesheet { get; construct; }

		private Gee.ArrayList<GLib.File> custom_stylesheet_files {
			get; default = new Gee.ArrayList<GLib.File>();
		}

		public Theme(
			GLib.File application_stylesheet,
			GLib.File theme_stylesheet,
			GLib.File default_stylesheet
		) {
			Object(
				application_stylesheet: application_stylesheet,
				theme_stylesheet: theme_stylesheet,
				default_stylesheet: default_stylesheet
			);
		}

		public GLib.List<weak GLib.File> get_custom_stylesheets()
		{
			var list = new GLib.List<weak GLib.File>();
			foreach (var file in this.custom_stylesheet_files) {
				list.append(file);
			}
			return (owned) list;
		}

		public bool load_stylesheet(GLib.File file) throws GLib.Error
		{
			this.custom_stylesheet_files.add(file);
			return true;
		}

		public void unload_stylesheet(GLib.File file)
		{
			var index = this.custom_stylesheet_files.index_of(file);
			if (index >= 0) {
				this.custom_stylesheet_files.remove_at(index);
			}
		}

		/**
		 * Wire URIs for {@link GnomeShellRpc.Rpc.Helper.ThemeContext.set_theme}.
		 */
		public string[] stylesheet_uris()
		{
			string[] uris = {};
			foreach (var file in this.custom_stylesheet_files) {
				var uri = file.get_uri();
				if (uri != null && uri != "") {
					uris += uri;
				}
			}
			return uris;
		}

		private static string file_uri(GLib.File? file)
		{
			if (file == null) {
				return "";
			}
			var uri = file.get_uri();
			return uri != null ? uri : "";
		}

		/**
		 * Construct-prop URIs in Helper order: application, theme, default.
		 */
		public void construct_uris(
			out string application_uri,
			out string theme_uri,
			out string default_uri
		) {
			application_uri = file_uri(this.application_stylesheet);
			theme_uri = file_uri(this.theme_stylesheet);
			default_uri = file_uri(this.default_stylesheet);
		}
