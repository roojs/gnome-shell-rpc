namespace Gsr.Server.Rpc
{
	/**
	 * {@code gsr-client} child: spawn, manual restart, crash screen.
	 *
	 * Client {@code Meta.restart} / {@code Meta.is_restart} call
	 * {@code Server-Rpc-SpawnClient}. This class does not register as {@code Meta}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * Gsr.Server.Rpc.SpawnClient.rpc_register();
	 * var spawn = new Gsr.Server.Rpc.SpawnClient(display, listen, socket_path);
	 * OLLMrpc.Request.register("Server-Rpc-SpawnClient", spawn);
	 * spawn.spawn_client();
	 * }}}
	 */
	public class SpawnClient : GLib.Object
	{
		private global::Meta.Display display;
		private Listen listen;
		private string rpc_socket_path;
		private global::Meta.WaylandClient? smoke_client = null;
		private GLib.Subprocess? client_proc = null;
		private bool manual_restart = false;
		private bool client_is_restart = false;
		private Gee.ArrayList<global::Clutter.Actor> crash_actors {
			get; set; default = new Gee.ArrayList<global::Clutter.Actor>();
		}

		public static void rpc_register()
		{
			OLLMrpc.Request.add_class(
				"Server-Rpc-SpawnClient", typeof(SpawnClient),
				"restart", "so",
				"is_restart", "",
				null);
		}

		/**
		 * @param display compositor display used to spawn and to paint the crash screen
		 * @param listen RPC listener; readiness and teardown run on its connections
		 * @param rpc_socket_path value exported as {@code MUTTER_RPC_SOCKET}
		 */
		public SpawnClient(
			global::Meta.Display display,
			Listen listen,
			string rpc_socket_path
		) {
			this.display = display;
			this.listen = listen;
			this.rpc_socket_path = rpc_socket_path;
		}

		/**
		 * Spawn the shell client via {@link global::Meta.WaylandClient}.
		 *
		 * Default (no {@code GI_META_SMOKE}, or {@code init}): {@code gsr-client}.
		 * Otherwise {@code gsr-smoke} and a {@code tests/gjs-embed/} script.
		 * Sets {@code MUTTER_RPC_SOCKET} and {@code WAYLAND_DISPLAY}.
		 */
		public void spawn_client(bool disable_extensions = false, bool force_debug = false)
		{
			var self_exe = "";
			try {
				self_exe = GLib.FileUtils.read_link("/proc/self/exe");
			} catch (GLib.Error e) {
				GLib.warning("client spawn: %s", e.message);
				return;
			}
			var bindir = GLib.Path.get_dirname(self_exe);
			var smoke_env = GLib.Environment.get_variable("GI_META_SMOKE");
			var use_init = smoke_env == null
				|| smoke_env.length == 0
				|| smoke_env == "init"
				|| smoke_env == "init.js";
			var client_name = use_init ? "gsr-client" : "gsr-smoke";
			var shell_bin = GLib.Path.build_filename(bindir, client_name);
			if (!GLib.FileUtils.test(shell_bin, GLib.FileTest.IS_EXECUTABLE)) {
				GLib.warning("%s missing next to %s — skip client spawn", client_name, self_exe);
				return;
			}

			string[] argv = { shell_bin };
			/* --debug on gsr-server, or a crash-screen choice that asks for it.
			 * The client stays quiet otherwise. */
			if (Gsr.debug_on || force_debug) {
				argv += "--debug";
			}
			if (disable_extensions) {
				argv += "--disable-extensions";
			}
			/* Nested boot: user extensions off via host memory settings. */
			if (!use_init) {
				var smoke_name = smoke_env;
				if (!smoke_name.has_suffix(".js")) {
					smoke_name += ".js";
				}
				var script = GLib.Path.build_filename(
					bindir, "..", "..", "tests", "gjs-embed", smoke_name);
				if (!GLib.FileUtils.test(script, GLib.FileTest.IS_REGULAR)) {
					GLib.warning("%s missing at %s — skip client spawn", smoke_name, script);
					return;
				}
				argv += script;
			}

#if GSR_GDB_SPAWN
			argv = GdbSpawnWrap.maybe_wrap_argv(argv);
#endif

			var launcher = new GLib.SubprocessLauncher(GLib.SubprocessFlags.NONE);
			if (this.rpc_socket_path.length > 0) {
				launcher.setenv("MUTTER_RPC_SOCKET", this.rpc_socket_path, true);
			}
			var wayland_display = GLib.Environment.get_variable("WAYLAND_DISPLAY");
			if (wayland_display != null && wayland_display.length > 0) {
				launcher.setenv("WAYLAND_DISPLAY", wayland_display, true);
			}
			try {
				this.smoke_client = new global::Meta.WaylandClient(
					this.display.get_context(), launcher);
				var proc = this.smoke_client.spawnv(this.display, argv);
				this.client_proc = proc;
				GLib.debug(
					"spawned %s pid=%s MUTTER_RPC_SOCKET=%s WAYLAND_DISPLAY=%s via global::Meta.WaylandClient",
					string.joinv(" ", argv),
					proc.get_identifier().to_string(),
					this.rpc_socket_path,
					wayland_display != null ? wayland_display : "(unset)"
				);
				GLib.Timeout.add_seconds(30, () => {
					if (this.client_proc != proc) {
						return GLib.Source.REMOVE;
					}
					foreach (var connection in this.listen.connections) {
						if (((Gsr.Server.Rpc.Connection) connection).ready) {
							return GLib.Source.REMOVE;
						}
					}
					GLib.warning("client not ready after 30s, killing it");
					proc.force_exit();
					return GLib.Source.REMOVE;
				});
				proc.wait_async.begin(null, (obj, res) => {
					try {
						proc.wait_async.end(res);
					} catch (GLib.Error e) {
						GLib.warning("client wait: %s", e.message);
					}
					if (this.client_proc != proc) {
						return;
					}
					this.client_proc = null;
					foreach (var connection in this.listen.connections.to_array()) {
						connection.stop();
					}
					this.listen.connections.clear();
					var manual_restart = this.manual_restart;
					this.manual_restart = false;
					GLib.debug("client exited manual-restart=%s", manual_restart.to_string());
					if (manual_restart) {
						this.client_is_restart = true;
						this.spawn_client();
						return;
					}
					this.client_is_restart = false;
					this.on_crash();
				});
			} catch (GLib.Error e) {
				GLib.warning("client spawn failed: %s", e.message);
				this.smoke_client = null;
				this.client_proc = null;
				return;
			}
		}

		/**
		 * Alt+F2 {@code r}. Ends this client so the wait callback spawns
		 * the next one. Does not call stock {@code meta_restart}.
		 */
		public void restart(OLLMrpc.Request request, string? message, global::Meta.Context context)
		{
			this.manual_restart = true;
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
			var proc = this.client_proc;
			GLib.Idle.add(() => {
				if (proc != null && this.client_proc == proc) {
					proc.force_exit();
				}
				return GLib.Source.REMOVE;
			});
		}

		/**
		 * True for the client spawned by a manual restart.
		 */
		public void is_restart(OLLMrpc.Request request)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", this.client_is_restart),
			});
		}

		/**
		 * Crash screen after every client exit. Mutter does not clear the
		 * stage, so a backdrop covers what the shell painted. "Log Out"
		 * sits on the backdrop under the windows; the notice with the
		 * choices sits over everything.
		 */
		private void on_crash()
		{
			var stage = this.display.get_context().get_backend().get_stage();
			var backdrop = new global::Clutter.Actor() {
				background_color = global::Cogl.Color.from_4f(0.0f, 0.0f, 0.0f, 1.0f),
			};
			backdrop.add_constraint(new global::Clutter.BindConstraint(
				stage, global::Clutter.BindCoordinate.SIZE, 0));
			stage.insert_child_below(backdrop, null);
			this.crash_actors.add(backdrop);
			var white = global::Cogl.Color.from_4f(1.0f, 1.0f, 1.0f, 1.0f);
			var logout = new global::Clutter.Text() {
				text = "Log Out",
				font_name = "Sans Bold 12",
				color = white,
				selectable = false,
				reactive = true,
				translation_x = -16.0f,
				translation_y = 12.0f,
			};
			logout.add_constraint(new global::Clutter.AlignConstraint(
				stage, global::Clutter.AlignAxis.X_AXIS, 1.0f));
			logout.button_release_event.connect((e) => {
				this.on_crash_logout();
				return true;
			});
			stage.insert_child_above(logout, backdrop);
			this.crash_actors.add(logout);
			var notice = new global::Clutter.Actor() {
				background_color = global::Cogl.Color.from_4f(0.0f, 0.0f, 0.0f, 0.9f),
				reactive = true,
			};
			notice.add_constraint(new global::Clutter.BindConstraint(
				stage, global::Clutter.BindCoordinate.SIZE, 0));
			var column = new global::Clutter.Actor() {
				layout_manager = new global::Clutter.BoxLayout() {
					orientation = global::Clutter.Orientation.VERTICAL,
					spacing = 12,
				},
			};
			column.add_constraint(new global::Clutter.AlignConstraint(
				notice, global::Clutter.AlignAxis.BOTH, 0.5f));
			column.add_child(new global::Clutter.Text() {
				text = "GNOME Shell has crashed.\n"
					+ "Your applications are still running. Choose how to continue.",
				font_name = "Sans 14",
				color = white,
				selectable = false,
				line_alignment = global::Pango.Alignment.CENTER,
				x_align = global::Clutter.ActorAlign.CENTER,
				margin_bottom = 12.0f,
			});
			this.crash_choice(column, "Restart").button_release_event.connect((e) => {
				foreach (var actor in this.crash_actors) {
					actor.destroy();
				}
				this.crash_actors.clear();
				this.spawn_client();
				return true;
			});
			this.crash_choice(column, "Restart with debug").button_release_event.connect((e) => {
				foreach (var actor in this.crash_actors) {
					actor.destroy();
				}
				this.crash_actors.clear();
				this.spawn_client(false, true);
				return true;
			});
			this.crash_choice(column, "Restart without extensions").button_release_event.connect((e) => {
				foreach (var actor in this.crash_actors) {
					actor.destroy();
				}
				this.crash_actors.clear();
				this.spawn_client(true, true);
				return true;
			});
			this.crash_choice(column, "Emergency mode").button_release_event.connect((e) => {
				this.crash_actors.remove(notice);
				notice.destroy();
				var mgr = this.display.get_workspace_manager();
				var active = mgr.get_active_workspace();
				var workspace = active != null ? active : mgr.get_workspace_by_index(0);
				if (workspace == null) {
					return true;
				}
				foreach (unowned global::Meta.Window window in this.display.list_all_windows()) {
					var type = window.get_window_type();
					if (window.is_override_redirect()
						|| type == global::Meta.WindowType.DESKTOP
						|| type == global::Meta.WindowType.DOCK) {
						continue;
					}
					if (!window.is_on_all_workspaces() && window.get_workspace() != workspace) {
						window.change_workspace(workspace);
					}
					if (window.minimized) {
						window.unminimize();
					}
				}
				return true;
			});
			this.crash_choice(column, "Log Out").button_release_event.connect((e) => {
				this.on_crash_logout();
				return true;
			});
			notice.add_child(column);
			stage.add_child(notice);
			this.crash_actors.add(notice);
		}

		/**
		 * One choice box on the crash notice, added to ''column''.
		 */
		private global::Clutter.Actor crash_choice(global::Clutter.Actor column, string label)
		{
			var box = new global::Clutter.Actor() {
				layout_manager = new global::Clutter.BinLayout(),
				background_color = global::Cogl.Color.from_4f(0.3f, 0.3f, 0.3f, 1.0f),
				width = 280.0f,
				height = 36.0f,
				reactive = true,
				x_align = global::Clutter.ActorAlign.CENTER,
			};
			box.add_child(new global::Clutter.Text() {
				text = label,
				font_name = "Sans Bold 12",
				color = global::Cogl.Color.from_4f(1.0f, 1.0f, 1.0f, 1.0f),
				selectable = false,
				x_expand = true,
				y_expand = true,
				x_align = global::Clutter.ActorAlign.CENTER,
				y_align = global::Clutter.ActorAlign.CENTER,
			});
			column.add_child(box);
			return box;
		}

		/**
		 * "Log Out" on the give-up screen. Exits this mutter immediately.
		 * SessionManager.Logout is rejected until the running phase, and
		 * waiting on it is what made the button sluggish.
		 */
		private void on_crash_logout()
		{
			this.display.get_context().terminate();
		}
	}
}
