namespace GnomeShellRpc.Ui
{
	/**
	 * Display RPC handler — queries and window mutations backed by
	 * {@link Meta.Display}.
	 *
	 * == Example ==
	 *
	 * {{{
	 * OLLMrpc.Request.register(
	 *     "Meta-Display",
	 *     new GnomeShellRpc.Ui.Display(meta_display),
	 *     typeof(GnomeShellRpc.Ui.DisplayParams));
	 * }}}
	 */
	public class Display : GLib.Object, OLLMrpc.Bin.Serializable
	{
		public static void rpc_register()
		{
			OLLMrpc.Bin.register("Display", typeof(Display));
			DisplayParams.rpc_register();
		}

		public Meta.Display meta_display { get; construct; }

		public int focused_window_id { get; set; default = 0; }
		public int workspace_count { get; set; default = 0; }

		public Display(Meta.Display meta_display)
		{
			GLib.Object(meta_display: meta_display);
		}

		public signal void call_list_windows(OLLMrpc.Request request);
		public signal void call_get_window(OLLMrpc.Request request);
		public signal void call_get_focused_window(OLLMrpc.Request request);
		public signal void call_minimize_window(OLLMrpc.Request request);
		public signal void call_unminimize_window(OLLMrpc.Request request);
		public signal void call_activate_window(OLLMrpc.Request request);
		public signal void call_close_window(OLLMrpc.Request request);

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

		construct
		{
			this.call_list_windows.connect((request) => {
				var response = new OLLMrpc.Response() {
					id = request.id,
				};
				foreach (unowned Meta.Window win in this.meta_display.list_all_windows()) {
					if (win == null) {
						continue;
					}
					var handle = (int)request.connection.export(win);
					var frame = win.get_frame_rect();
					var wm = win.get_wm_class();
					response.result.add(new Window() {
						id = handle,
						title = win.get_title(),
						wm_class = wm != null ? wm : "",
						minimized = win.minimized,
						maximized = win.get_maximized() != 0,
						frame_rect = new Shared.Rectangle() {
							x = frame.x,
							y = frame.y,
							width = frame.width,
							height = frame.height,
						},
					});
				}
				request.reply(response);
			});

			this.call_get_window.connect((request) => {
				var p = (WindowParams)request.param;
				if (!request.connection.leases.has_key(p.object_id)) {
					request.reply(new OLLMrpc.Response() {
						id = request.id,
						error = new OLLMrpc.Error(
							(int)OLLMrpc.RpcErrorCode.INVALID_PARAMS,
							"window handle not found"
						),
					});
					return;
				}
				var meta = (Meta.Window)request.connection.leases.get(p.object_id);
				var frame = meta.get_frame_rect();
				var wm = meta.get_wm_class();
				var response = new OLLMrpc.Response() {
					id = request.id,
				};
				response.result.add(new Window() {
					id = p.object_id,
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
				});
				request.reply(response);
			});

			this.call_get_focused_window.connect((request) => {
				var focus = this.meta_display.get_focus_window();
				if (focus == null) {
					request.reply(new OLLMrpc.Response() {
						id = request.id,
					});
					return;
				}
				var handle = (int)request.connection.export(focus);
				var frame = focus.get_frame_rect();
				var wm = focus.get_wm_class();
				var response = new OLLMrpc.Response() {
					id = request.id,
				};
				response.result.add(new Window() {
					id = handle,
					title = focus.get_title(),
					wm_class = wm != null ? wm : "",
					minimized = focus.minimized,
					maximized = focus.get_maximized() != 0,
					frame_rect = new Shared.Rectangle() {
						x = frame.x,
						y = frame.y,
						width = frame.width,
						height = frame.height,
					},
				});
				request.reply(response);
			});

			this.call_minimize_window.connect((request) => {
				var p = (WindowParams)request.param;
				if (!request.connection.leases.has_key(p.object_id)) {
					request.reply(new OLLMrpc.Response() {
						id = request.id,
						error = new OLLMrpc.Error(
							(int)OLLMrpc.RpcErrorCode.INVALID_PARAMS,
							"window handle not found"
						),
					});
					return;
				}
				var meta = (Meta.Window)request.connection.leases.get(p.object_id);
				meta.minimize();
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
			});

			this.call_unminimize_window.connect((request) => {
				var p = (WindowParams)request.param;
				if (!request.connection.leases.has_key(p.object_id)) {
					request.reply(new OLLMrpc.Response() {
						id = request.id,
						error = new OLLMrpc.Error(
							(int)OLLMrpc.RpcErrorCode.INVALID_PARAMS,
							"window handle not found"
						),
					});
					return;
				}
				var meta = (Meta.Window)request.connection.leases.get(p.object_id);
				meta.unminimize();
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
			});

			this.call_activate_window.connect((request) => {
				var p = (WindowParams)request.param;
				if (!request.connection.leases.has_key(p.object_id)) {
					request.reply(new OLLMrpc.Response() {
						id = request.id,
						error = new OLLMrpc.Error(
							(int)OLLMrpc.RpcErrorCode.INVALID_PARAMS,
							"window handle not found"
						),
					});
					return;
				}
				var meta = (Meta.Window)request.connection.leases.get(p.object_id);
				meta.activate(this.meta_display.get_current_time());
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
			});

			this.call_close_window.connect((request) => {
				var p = (WindowParams)request.param;
				if (!request.connection.leases.has_key(p.object_id)) {
					request.reply(new OLLMrpc.Response() {
						id = request.id,
						error = new OLLMrpc.Error(
							(int)OLLMrpc.RpcErrorCode.INVALID_PARAMS,
							"window handle not found"
						),
					});
					return;
				}
				var meta = (Meta.Window)request.connection.leases.get(p.object_id);
				meta.delete(this.meta_display.get_current_time());
				request.reply(new OLLMrpc.Response() {
					id = request.id,
				});
			});
		}
	}
}
