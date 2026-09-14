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
			var stub = (WaylandClient) response.retval.get_object();
			this.rpc_lid = stub.rpc_lid;
		}

		private GLib.SubprocessLauncher? local_launcher = null;

		/**
		 * Stock {@code meta_wayland_client_spawnv}. Returns
		 * {@link Meta.RpcSubprocess} (Gio.Subprocess is foreign / not on wire).
		 *
		 * {@code GLib.SubprocessLauncher} has no get_cwd in our Gio — cwd is
		 * sent empty; callers that need a cwd should use absolute argv (DING).
		 */
		public RpcSubprocess? spawnv(Display display, string[] argv)
			throws GLib.Error
		{
			var response = GnomeShellRpc.call_value(
				"Helper-WaylandClient.spawnv", this,
				OLLMrpc.args("osS", display, "", argv)
			);
			int stdout_fd = -1;
			if (response.buffer != null && response.buffer.fd >= 0) {
				stdout_fd = response.buffer.fd;
				response.buffer.fd = -1;
			}
			return new RpcSubprocess(this.rpc_lid, stdout_fd);
		}
