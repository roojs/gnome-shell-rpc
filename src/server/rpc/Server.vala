namespace Gsr.Server.Rpc
{
	/**
	 * RPC server boot — socket, registrations, display/window notifications.
	 * {@link SpawnClient} spawns {@code gsr-client}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * new Gsr.Server.Rpc.Server().start(meta_display);
	 * }}}
	 */
	public class Server : GLib.Object
	{
		public global::Meta.Display display { get; private set; }
		public Listen listen { get; private set; }
		public Gsr.Server.Meta.Display ui_display { get; private set; }
		private SpawnClient spawn { get; set; }

		private Gee.HashMap<global::Meta.Window, ulong> title_watch_ids =
			new Gee.HashMap<global::Meta.Window, ulong>();
		private bool window_actor_aliased = false;

		public void start(global::Meta.Display display)
		{
			this.display = display;
			var frame_lock = new StartupFrameLock(display);
			OLLMrpc.rpc_register(true);
			/* Prefer error codes on Callback.reply → reply_error (throws). */
			LiveCallback.rpc_register();
			Gsr.Shared.rpc_register();
			Gsr.Server.Meta.Display.rpc_register();
			Gsr.Server.Meta.Compositor.rpc_register();
			Daemon.rpc_register();
			Bootstrap.rpc_register();
			SpawnClient.rpc_register();

			GI.Repository.prepend_search_path(MUTTER_TYPELIB_DIR);
			GI.Repository.prepend_search_path(GNOME_SHELL_PKGLIBDIR);
			OLLMrpc.Gi.register("Meta", "16");
			OLLMrpc.Gi.register("Clutter", "16");
			OLLMrpc.Gi.register("St", "16");
			/* Opaque boxed ClutterStage::before-update arg. */
			OLLMrpc.Bin.register("Clutter-Frame", typeof(global::Clutter.Frame));

			Cancellable.rpc_register();
			Gsr.Server.Meta.rpc_register(frame_lock);
			Gsr.Server.Clutter.rpc_register();
			Gsr.Server.St.rpc_register();
			Gsr.Server.Shell.rpc_register();

			Gsr.Server.Meta.bind(display);
			Gsr.Server.Shell.bind(display);

			OLLMrpc.Request.register("RPC-Daemon", new Daemon());

			this.ui_display = new Gsr.Server.Meta.Display(display);
			Gsr.Server.Meta.register_alias(display, this.ui_display);

			/* --wayland --nested is the X11 nested backend.
			 * Monitor manager is a subclass on this nested boot too.
			 * It is not native-only. */
			var monitor_manager = display.get_context().get_backend().get_monitor_manager();
			if (!OLLMrpc.Bin.gtype_to_alias.has_key(monitor_manager.get_type())) {
				OLLMrpc.Bin.register_alias("Meta-MonitorManager", monitor_manager.get_type());
			}
			var stage = display.get_context().get_backend().get_stage();
			Gsr.Server.Clutter.register_alias(stage);

			var bootstrap = Bootstrap.bind(this.display, frame_lock);
			OLLMrpc.Request.register("Server-Bootstrap", bootstrap);

			var socket_path = GLib.Environment.get_variable("MUTTER_RPC_SOCKET");
			if (socket_path == null || socket_path.length == 0) {
				var runtime = GLib.Environment.get_variable("XDG_RUNTIME_DIR");
				if (runtime == null || runtime.length == 0) {
					GLib.error("XDG_RUNTIME_DIR is unset");
				}
				socket_path = GLib.Path.build_filename(runtime, "mutter-rpc.sock");
			}

			this.listen = new Listen(socket_path) {
				live_handles = true,
			};
			this.spawn = new SpawnClient(this.display, this.listen, socket_path);
			OLLMrpc.Request.register("Server-Rpc-SpawnClient", this.spawn);
			this.listen.connection_ready.connect((connection) => {
				foreach (var view in stage.peek_stage_views()) {
					connection.export(view);
				}
				/* Stock layout.js shutdown: the shell reparents these mutter
				 * groups into uiGroup. Put them back on the stage before
				 * destroying the shell's actors, or they die with uiGroup. */
				var compositor = this.display.get_compositor();
				global::Clutter.Actor[] adopted = {
					compositor.get_window_group(),
					compositor.get_top_window_group(),
					compositor.get_feedback_group(),
				};
				var doomed = new Gee.ArrayList<global::Clutter.Actor>();
				var conn = (Gsr.Server.Rpc.Connection) connection;
				conn.stopping.connect((c) => {
					foreach (var lease in c.leases.values) {
						// FIXME - this is shit
						var hooked = lease as Gsr.Server.Clutter.Actor;
						if (hooked != null) {
							hooked.vfuncs.clear();
						}
						var actor = lease as global::Clutter.Actor;
						if (actor == null
							|| actor is global::Meta.WindowActor
							|| actor in adopted) {
							continue;
						}
						var parent = actor.get_parent();
						if (parent == stage || parent == adopted[0]) {
							doomed.add(actor);
						}
					}
				});
				conn.stopped.connect(() => {
					foreach (var group in adopted) {
						var parent = group.get_parent();
						if (parent == stage) {
							continue;
						}
						if (parent != null) {
							parent.remove_child(group);
						}
						stage.add_child(group);
					}
					foreach (var actor in doomed) {
						actor.destroy();
					}
					doomed.clear();
				});
			});
			if (!this.listen.start()) {
				GLib.error("failed to start RPC listener on %s", socket_path);
			}
			GLib.debug("listening on %s", socket_path);
			this.spawn.spawn_client();

			display.window_created.connect((meta_window) => {
				if (this.listen != null) {
					foreach (var connection in this.listen.connections) {
						connection.export(meta_window);
					}
				}
				if (!this.window_actor_aliased) {
					var priv = meta_window.get_compositor_private();
					if (priv != null) {
						try {
							OLLMrpc.Bin.register_alias("Meta-WindowActor",
								priv.get_type());
							this.window_actor_aliased = true;
						} catch (GLib.Error e) {
							GLib.error("%s", e.message);
						}
					}
				}
				var frame = meta_window.get_frame_rect();
				GLib.debug("window_created title=%s frame=%d,%d %dx%d minimized=%s",
					meta_window.get_title(), frame.x, frame.y, frame.width,
					frame.height, meta_window.minimized.to_string());
				this.track_window(meta_window);
				if (this.listen == null) {
					return;
				}
				foreach (var connection in this.listen.connections) {
					var handle = (int)connection.export(meta_window);
					connection.write(new OLLMrpc.Notification() {
						method = "Window.created",
						object_type = "Window",
						id = handle,
					});
				}
			});

			foreach (unowned global::Meta.Window win in display.list_all_windows()) {
				this.track_window(win);
			}
		}

		private uint64? lease_handle_for(
			OLLMrpc.Transport.Connection connection,
			global::Meta.Window meta_window)
		{
			var ptr = (uint64) (void*) meta_window;
			var hi = (int) (ptr >> 32);
			var lo = (int) ptr;
			if (!connection.lease_ids.has_key(hi)) {
				return null;
			}
			var inner = connection.lease_ids.get(hi);
			if (!inner.has_key(lo)) {
				return null;
			}
			return (uint64) inner.get(lo);
		}

		private void track_window(global::Meta.Window meta_window)
		{
			meta_window.unmanaged.connect(() => {
				if (this.listen == null) {
					return;
				}
				foreach (var connection in this.listen.connections) {
					var handle = this.lease_handle_for(connection, meta_window);
					if (handle == null) {
						continue;
					}
					connection.write(new OLLMrpc.Notification() {
						method = "Window.closed",
						object_type = "Window",
						id = (int) handle,
					});
				}
				if (this.title_watch_ids.has_key(meta_window)) {
					meta_window.disconnect(this.title_watch_ids.get(meta_window));
					this.title_watch_ids.unset(meta_window);
				}
			});

			if (this.title_watch_ids.has_key(meta_window)) {
				return;
			}

			var watch_id = meta_window.notify["title"].connect(() => {
				if (this.listen == null) {
					return;
				}
				foreach (var connection in this.listen.connections) {
					var handle = this.lease_handle_for(connection, meta_window);
					if (handle == null) {
						continue;
					}
					var title = GLib.Value(typeof(string));
					title.set_string(meta_window.title ?? "");
					var packed = new Gee.ArrayList<GLib.Value?>();
					packed.add(title);
					connection.write(new OLLMrpc.Notification() {
						method = "notify::title",
						object_type = "Window",
						id = (int) handle,
						args = packed,
					});
				}
			});
			this.title_watch_ids.set(meta_window, watch_id);
		}
	}
}
