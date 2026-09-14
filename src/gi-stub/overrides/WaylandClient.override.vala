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

		/**
		 * Stock {@code meta_wayland_client_spawnv}. Returns
		 * {@link Meta.RpcSubprocess} (Gio.Subprocess is foreign / not on wire).
		 *
		 * Wire args: display, cwd, then one {@code s} per argv element.
		 * (Ffi {@code as} hangs / drops the strv on this Helper path.)
		 */
		public RpcSubprocess? spawnv(
			Display display,
			[CCode (array_length = false, array_null_terminated = true)]
			string[] argv
		) throws GLib.Error {
			string[] wire = {};
			if (argv != null) {
				for (int i = 0; argv[i] != null; i++) {
					wire += argv[i];
				}
			}
			GLib.message(
				"WaylandClient.spawnv client argv_len=%d",
				wire.length
			);
			/* cwd: Gio SubprocessLauncher has set_cwd, no get_cwd. */
			var packed = OLLMrpc.args("os", display, "");
			foreach (var s in wire) {
				packed.add(OLLMrpc.val("s", s));
			}
			var response = GnomeShellRpc.call_value(
				"Helper-WaylandClient.spawnv", this, packed
			);
			int stdout_fd = -1;
			if (response.buffer != null && response.buffer.fd >= 0) {
				stdout_fd = response.buffer.fd;
				response.buffer.fd = -1;
			}
			return new RpcSubprocess(this.rpc_lid, stdout_fd);
		}
