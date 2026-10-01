		/**
		 * Stock {@code meta_backend_get_settings} is {@code introspectable="0"}.
		 * Body is {@code c-meta-shell-gaps.c}. The method name would clash
		 * with that C symbol.
		 */
		[CCode (cname = "gsr_meta_backend_get_settings_vala")]
		private extern void* get_settings_ptr();

		[CCode (cname = "gsr_meta_backend_get_settings_method")]
		public GLib.Object get_settings()
		{
			return (GLib.Object) this.get_settings_ptr();
		}
