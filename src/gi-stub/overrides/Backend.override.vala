		/**
		 * Stock {@code meta_backend_get_settings} is {@code introspectable="0"}.
		 * C export: {@code c-meta-shell-gaps.c}; Vala calls {@code gsr_meta_backend_get_settings_vala}.
		 */
		[CCode (cname = "gsr_meta_backend_get_settings_method")]
		public GLib.Object get_settings()
		{
			return GnomeShellRpc.GiStub.meta_backend_get_settings(this);
		}
