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

		/**
		 * Stock {@code meta_backend_get_keymap_description}. The reply
		 * lease is the compositor's current description.
		 *
		 * @return proxy for that description
		 */
		[CCode (cname = "gsr_meta_backend_get_keymap_description")]
		public KeymapDescription get_keymap_description()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Backend.get_keymap_description", this);
			return (KeymapDescription) GLib.Object.new(
				typeof(KeymapDescription),
				"rpc-lid", response.args.get(0).get_uint64());
		}

		/**
		 * Stock {@code meta_backend_set_keymap_async}. The call site
		 * passes a null cancellable. The reply is the finished apply.
		 *
		 * @param description keymap to apply
		 * @param layout_index group to select
		 * @param cancellable unused at the Shell 50 call site
		 * @param callback invoked once the compositor has applied it
		 */
		[CCode (cname = "gsr_meta_backend_set_keymap_async")]
		public void set_keymap_async(
			KeymapDescription description,
			uint32 layout_index,
			GLib.Cancellable? cancellable,
			owned GLib.AsyncReadyCallback callback
		) {
			Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-Backend.set_keymap",
				this,
				OLLMrpc.args("tu", description.rpc_lid, layout_index));
			var task = new GLib.Task(this, cancellable, null);
			task.return_boolean(true);
			callback(this, task);
		}

		/**
		 * Stock {@code meta_backend_set_keymap_finish}.
		 * {@code Gio._promisify} calls this after
		 * {@link set_keymap_async}. The apply already finished.
		 *
		 * @param result task from {@link set_keymap_async}
		 * @return whether the apply succeeded
		 */
		[CCode (cname = "gsr_meta_backend_set_keymap_finish")]
		public bool set_keymap_finish(GLib.AsyncResult result)
		{
			var task = result as GLib.Task;
			if (task == null) {
				return false;
			}
			try {
				return task.propagate_boolean();
			} catch (GLib.Error e) {
				return false;
			}
		}
