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
