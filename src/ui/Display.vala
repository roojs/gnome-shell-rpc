namespace GnomeShellRpc.Ui
{
	/**
	 * Display RPC handler — queries and window mutations backed by
	 * {@link Meta.Display}.
	 *
	 * Wire prefix {@code Meta-Display}. {@link OLLMrpc.Request.register_live}
	 * keeps this singleton as {@code this}; {@code lease_id} is not the
	 * handler. Live GObject getters ({@code get_compositor}, …) fall through
	 * to typelib {@link OLLMrpc.Gi} on the leased {@link Meta.Display}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * GnomeShellRpc.Ui.Display.rpc_register();
	 * OLLMrpc.Request.register_live("Meta-Display",
	 *     new GnomeShellRpc.Ui.Display(meta_display));
	 * }}}
	 */
	public class Display : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Display", typeof(Display));
			OLLMrpc.Request.add_class(
				"Meta-Display", typeof(Display),
				"list_windows", "",
				"get_window", "i",
				"get_focused_window", "",
				"get_startup_notification", "",
				"minimize_window", "i",
				"unminimize_window", "i",
				"activate_window", "i",
				"close_window", "i",
				null
			);
		}

		public Meta.Display meta_display { get; construct; }

		public int focused_window_id { get; set; default = 0; }
		public int workspace_count { get; set; default = 0; }

		public Display(Meta.Display meta_display)
		{
			GLib.Object(meta_display: meta_display);
		}

		public override void bin_write_prop(
			OLLMrpc.Bin.Stream ctx,
			GLib.ParamSpec prop
		) throws GLib.Error
		{
			if (prop.name == "meta-display") {
				return;
			}
			bin_default_write_prop(ctx, prop);
		}

		public override void bin_read_prop(
			OLLMrpc.Bin.Stream ctx,
			GLib.ParamSpec prop,
			uint8 type_byte
		) throws GLib.Error
		{
			if (prop.name == "meta-display") {
				return;
			}
			bin_default_read_prop(ctx, prop, type_byte);
		}

		/**
		 * ''Meta-Display.list_windows'' — snapshot every known window.
		 *
		 * @param request inbound RPC
		 */
		public void list_windows(OLLMrpc.Request request)
		{
			var list = new Gee.ArrayList<GLib.Object>();
			foreach (unowned Meta.Window win in this.meta_display.list_all_windows()) {
				if (win == null) {
					continue;
				}
				var handle = (int) request.connection.export(win);
				list.add(this.snapshot_window(win, handle));
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", list),
			});
		}

		/**
		 * ''Meta-Display.get_window'' — snapshot one leased window.
		 *
		 * @param request inbound RPC
		 * @param object_id window lease id
		 */
		public void get_window(OLLMrpc.Request request, int object_id)
		{
			var meta = this.window_from_id(request, object_id);
			if (meta == null) {
				return;
			}
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", this.snapshot_window(meta, object_id)),
			});
		}

		/**
		 * ''Meta-Display.get_focused_window'' — snapshot of focus, or empty.
		 *
		 * @param request inbound RPC
		 */
		public void get_focused_window(OLLMrpc.Request request)
		{
			var focus = this.meta_display.get_focus_window();
			if (focus == null) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
				return;
			}
			var handle = (int) request.connection.export(focus);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", this.snapshot_window(focus, handle)),
			});
		}

		/**
		 * ''Meta-Display.get_startup_notification'' — live object in retval.
		 *
		 * Typelib marks the stock method non-introspectable, so Gi cannot
		 * dispatch it; hand handler exports and returns the real object.
		 *
		 * @param request inbound RPC
		 */
		public void get_startup_notification(OLLMrpc.Request request)
		{
			var sn = this.meta_display.get_startup_notification();
			request.connection.export(sn);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", sn),
			});
		}

		/**
		 * ''Meta-Display.minimize_window''
		 *
		 * @param request inbound RPC
		 * @param object_id window lease id
		 */
		public void minimize_window(OLLMrpc.Request request, int object_id)
		{
			var meta = this.window_from_id(request, object_id);
			if (meta == null) {
				return;
			}
			meta.minimize();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * ''Meta-Display.unminimize_window''
		 *
		 * @param request inbound RPC
		 * @param object_id window lease id
		 */
		public void unminimize_window(OLLMrpc.Request request, int object_id)
		{
			var meta = this.window_from_id(request, object_id);
			if (meta == null) {
				return;
			}
			meta.unminimize();
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * ''Meta-Display.activate_window''
		 *
		 * @param request inbound RPC
		 * @param object_id window lease id
		 */
		public void activate_window(OLLMrpc.Request request, int object_id)
		{
			var meta = this.window_from_id(request, object_id);
			if (meta == null) {
				return;
			}
			meta.activate(this.meta_display.get_current_time());
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		/**
		 * ''Meta-Display.close_window''
		 *
		 * @param request inbound RPC
		 * @param object_id window lease id
		 */
		public void close_window(OLLMrpc.Request request, int object_id)
		{
			var meta = this.window_from_id(request, object_id);
			if (meta == null) {
				return;
			}
			meta.delete(this.meta_display.get_current_time());
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		private Window snapshot_window(Meta.Window meta, int handle)
		{
			var frame = meta.get_frame_rect();
			var wm = meta.get_wm_class();
			return new Window() {
				id = handle,
				title = meta.get_title(),
				wm_class = wm != null ? wm : "",
				minimized = meta.minimized,
				maximized = meta.get_maximized() != 0,
				frame_rect = new Shared.Rectangle() {
					x = frame.x,
					y = frame.y,
					width = frame.width,
					height = frame.height,
				},
			};
		}

		/**
		 * Lease id → mutter window, or reply INVALID_PARAMS.
		 *
		 * @return window, or {@code null} when this method already replied
		 */
		private Meta.Window? window_from_id(OLLMrpc.Request request, int object_id)
		{
			if (!request.connection.leases.has_key(object_id)) {
				request.reply(new OLLMrpc.Response() {
					id = request.id,
					error = new OLLMrpc.Error(
						(int) OLLMrpc.RpcErrorCode.INVALID_PARAMS,
						"window handle not found"
					),
				});
				return null;
			}
			return (Meta.Window) request.connection.leases.get(object_id);
		}
	}
}
