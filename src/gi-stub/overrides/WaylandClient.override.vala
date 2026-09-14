		/**
		 * Stock {@code meta_wayland_client_new}. Launcher stays local; flags
		 * cross the wire. Compositor builds the real launcher + client.
		 */
		public WaylandClient(Context context, GLib.SubprocessLauncher launcher)
			throws GLib.Error
		{
			Object();
			this.local_launcher = launcher;
			uint flags = 0;
			var fv = GLib.Value(typeof(GLib.SubprocessFlags));
			launcher.get_property("flags", ref fv);
			flags = fv.get_flags();
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
				OLLMrpc.args("oas", display, "", argv)
			);
			int stdout_fd = -1;
			if (response.buffer != null && response.buffer.fd >= 0) {
				stdout_fd = response.buffer.fd;
				response.buffer.fd = -1;
			}
			return new RpcSubprocess(this.rpc_lid, stdout_fd);
		}
