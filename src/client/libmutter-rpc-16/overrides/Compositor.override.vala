		/**
		 * Stock {@code meta_compositor_get_window_actors}. Each arg
		 * pair is the actor object, then its window object. Decode
		 * reuses a proxy already stored for that lease. An actor
		 * with no window is left out of the list.
		 */
		public GLib.List<WindowActor> get_window_actors()
		{
			var response = Gsr.Client.Rpc.call_value(
				"Meta-Compositor.get_window_actors", this);
			var list = new GLib.List<WindowActor>();
			var n = response.args.size;
			for (var i = 0; i + 1 < n; i += 2) {
				var actor_val = response.args.get(i);
				var win_val = response.args.get(i + 1);
				if (!actor_val.type().is_a(typeof(GLib.Object))
					|| !win_val.type().is_a(typeof(GLib.Object))) {
					continue;
				}
				var actor = actor_val.get_object() as WindowActor;
				var win = win_val.get_object() as Window;
				if (actor == null || win == null) {
					continue;
				}
				if (actor.bound_meta_window == null) {
					actor.bound_meta_window = win;
				}
				list.append(actor);
			}
			return list;
		}
