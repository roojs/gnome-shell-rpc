		/**
		 * Stock {@code meta_compositor_get_window_actors} — hydrate live
		 * actor proxies from the server's handle pairs.
		 *
		 * The generated stub expects a {@code Gee.ArrayList} retval, but
		 * the server packs hand-rolled uint64 args (actor lease, window
		 * lease per actor), so the generated decode silently yields an
		 * empty list and stock {@code Workspace} construction bulk-adds
		 * nothing. Each hydrated actor binds its window up front, the
		 * same way {@code Display.list_all_windows} hydrates windows
		 * from snapshot rows.
		 */
		public GLib.List<WindowActor> get_window_actors()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Meta-Compositor.get_window_actors", this);
			var list = new GLib.List<WindowActor>();
			var n = response.args.size;
			for (var i = 0; i + 1 < n; i += 2) {
				var actor_lid = response.args.get(i).get_uint64();
				var win_lid = response.args.get(i + 1).get_uint64();
				if (actor_lid == 0 || win_lid == 0) {
					continue;
				}
				var win = new Window();
				win.rpc_lid = win_lid;
				Gsr.Client.Rpc.register_handle(win);
				var actor = new WindowActor();
				actor.rpc_lid = actor_lid;
				actor.bound_meta_window = win;
				Gsr.Client.Rpc.register_handle(actor);
				list.append(actor);
			}
			return list;
		}
