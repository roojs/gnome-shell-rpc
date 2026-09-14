		/**
		 * Stock {@code meta_wayland_client_new}. Launcher stays local; flags
		 * cross the wire. Compositor builds the real launcher + client.
		 */
		public WaylandClient(Context context, GLib.SubprocessLauncher launcher)
			throws GLib.Error
		{
			Object();
			this.local_launcher = launcher;
			/* Gio.SubprocessLauncher.flags is construct-only (no getter).
			 * DING and peers always want a merged stdout pipe. */
			uint flags = (uint) (
				GLib.SubprocessFlags.STDOUT_PIPE
				| GLib.SubprocessFlags.STDERR_MERGE
			);
			var response = GnomeShellRpc.call_value(
				"Helper-WaylandClient.create", null,
				OLLMrpc.args("ou", context, flags)
			);
			this.rpc_lid = response.args.get(0).get_uint64();
		}

		private GLib.SubprocessLauncher? local_launcher = null;

		/* Gio has set_cwd, no get_cwd — peek private layout (glib ≥2.40). */
		[CCode (cname = "gsr_subprocess_launcher_peek_cwd")]
		private static extern unowned string? peek_launcher_cwd(
			GLib.SubprocessLauncher launcher
		);

		/**
		 * Stock {@code meta_wayland_client_spawnv}. Returns
		 * {@link Meta.RpcSubprocess} (Gio.Subprocess is foreign / not on wire).
		 *
		 * Wire pack: {@code osas} (display, cwd, string[]). Helper
		 * {@code add_class} uses {@code osS} so Vala gets array length.
		 */
		public RpcSubprocess? spawnv(
			Display display,
			[CCode (array_length = false, array_null_terminated = true)]
			string[] argv
		) throws GLib.Error {
			/* Stock argv is null-terminated; pack needs length-bearing. */
			string[] wire = {};
			if (argv != null) {
				for (int i = 0; argv[i] != null; i++) {
					wire += argv[i];
				}
			}
			string cwd = "";
			if (this.local_launcher != null) {
				unowned string? peeked = peek_launcher_cwd(this.local_launcher);
				if (peeked != null) {
					cwd = peeked;
				}
			}
			GLib.message(
				"WaylandClient.spawnv client argv_len=%d cwd='%s'",
				wire.length, cwd
			);
			var response = GnomeShellRpc.call_value(
				"Helper-WaylandClient.spawnv", this,
				OLLMrpc.args("osas", display, cwd, wire)
			);
			int stdout_fd = -1;
			if (response.buffer != null && response.buffer.fd >= 0) {
				stdout_fd = response.buffer.fd;
				response.buffer.fd = -1;
			}
			return new RpcSubprocess(this.rpc_lid, stdout_fd);
		}
