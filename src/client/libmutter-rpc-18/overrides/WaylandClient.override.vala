		/**
		 * Stock {@code meta_wayland_client_new_subprocess}. The cname
		 * is that GIR symbol. Without it Vala emits
		 * {@code meta_wayland_client_new_new_subprocess}, GJS does not
		 * bind the invoker, and {@code Function::invoke} aborts.
		 * Launcher stays local. Flags, cwd, and argv cross the wire.
		 * The compositor builds the real launcher and launches.
		 */
		[CCode (cname = "meta_wayland_client_new_subprocess")]
		public WaylandClient.new_subprocess(
			Context context,
			GLib.SubprocessLauncher launcher,
			[CCode (array_length = false, array_null_terminated = true)]
			string[] argv
		) throws GLib.Error {
			Object();
			/* Gio.SubprocessLauncher.flags is construct-only (no getter).
			 * DING and peers always want a merged stdout pipe. */
			uint flags = (uint) (
				GLib.SubprocessFlags.STDOUT_PIPE
				| GLib.SubprocessFlags.STDERR_MERGE
			);
			string[] wire = {};
			if (argv != null) {
				for (int i = 0; argv[i] != null; i++) {
					wire += argv[i];
				}
			}
			string cwd = "";
			if (launcher != null) {
				unowned string? peeked = peek_launcher_cwd(launcher);
				if (peeked != null) {
					cwd = peeked;
				}
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-WaylandClient.new_subprocess",
				null,
				OLLMrpc.args("ousas", context, flags, cwd, wire)
			);
			this.rpc_lid = response.args.get(0).get_uint64();
			if (response.buffer != null && response.buffer.fd >= 0) {
				this.stdout_fd = response.buffer.fd;
				response.buffer.fd = -1;
			}
		}

		private RpcSubprocess? subprocess = null;
		private int stdout_fd = -1;

		/* Gio has set_cwd, no get_cwd — peek private layout (glib ≥2.40). */
		[CCode (cname = "gsr_subprocess_launcher_peek_cwd")]
		private static extern unowned string? peek_launcher_cwd(
			GLib.SubprocessLauncher launcher
		);

		/**
		 * Stock {@code meta_wayland_client_get_subprocess}. Returns
		 * {@link Meta.RpcSubprocess}. Gio.Subprocess is foreign and
		 * not on the wire. The stdout fd arrived with
		 * {@code new_subprocess}.
		 */
		public RpcSubprocess get_subprocess()
		{
			if (this.subprocess != null) {
				return this.subprocess;
			}
			this.subprocess = new RpcSubprocess(this.rpc_lid, this.stdout_fd);
			this.stdout_fd = -1;
			return this.subprocess;
		}

		/**
		 * Stock {@code meta_wayland_client_owns_window}.
		 */
		public bool owns_window(Window window) throws GLib.Error
		{
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-WaylandClient.owns_window", this,
				OLLMrpc.args("o", window)
			);
			if (response.retval.type() == GLib.Type.INVALID) {
				return false;
			}
			return response.retval.get_boolean();
		}
