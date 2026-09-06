namespace GnomeShellRpc.GiRpcMock
{
	/**
	 * Hand mock for wires {@link OLLMrpc.GiMock} cannot answer correctly.
	 *
	 * ************************************************************************
	 * DO NOT ADD Meta/Clutter/St arms willy-nilly.
	 *
	 * When dispatch returns false, libocrpc runs GiMock: GIR-typed empty
	 * replies + ctor lease mint. That is the default.
	 *
	 * Only add a hand arm when GiMock is wrong for THIS call:
	 *   - Must return a {@link MockBootGraph} singleton (not a fresh mint)
	 *     e.g. get_stage -> boot.stage
	 *   - Helper-* / non-GIR wire
	 *   - Scalar / OUT shape GiMock empties would break boot
	 *   - Process control (Context.terminate -> exit)
	 *
	 * If GiMock already returns the right empty/mint: return false.
	 * ************************************************************************
	 *
	 * @see OLLMrpc.GiMock
	 * @see OLLMrpc.Request.register_mock
	 */
	public class HelperMock : GLib.Object, OLLMrpc.MockDispatch
	{
		/**
		 * Child actor lease → parent object (from {@code add_child} / insert).
		 * Keys are connection lease ids ({@code int}, same as
		 * {@link OLLMrpc.Connection.leases}).
		 */
		private Gee.HashMap<int, GLib.Object> actor_parents {
			get; set; default = new Gee.HashMap<int, GLib.Object>();
		}

		/**
		 * Sink parent for actors never seen in {@code add_child}. GiMock
		 * {@code get_parent} mints forever; always-null breaks ScreenshotUI
		 * {@code close()} which needs a non-null parent to {@code remove_child}.
		 * The sink's own {@code get_parent} returns null (see
		 * {@link orphan_parent_id}).
		 */
		private GLib.Object? orphan_parent { get; set; default = null; }
		private int orphan_parent_id { get; set; default = 0; }

		public bool dispatch(OLLMrpc.Request request)
		{
			var method = request.method;
			if (!method.has_prefix("Helper-")
				&& !method.has_prefix("Meta-")
				&& !method.has_prefix("St-")
				&& !method.has_prefix("Clutter-")
				&& !method.has_prefix("Shell-")) {
				return false;
			}

			var dot = method.index_of_char('.');
			if (dot < 0) {
				return false;
			}
			var prefix = method.substring(0, dot);
			var name = method.substring(dot + 1);
			var boot = MockBootGraph.get();

			switch (prefix) {
				/* —— MockBootGraph singletons (GiMock would mint a new object) —— */
				case "Meta-Display":
					switch (name) {
						case "get_context":
							this.reply_retval_leased(request, boot.context);
							return true;
						case "get_compositor":
							this.reply_retval_leased(request, boot.compositor);
							return true;
						case "get_workspace_manager":
							this.reply_retval_leased(request, boot.workspace_manager);
							return true;
						case "get_startup_notification":
							this.reply_retval_leased(request, boot.startup_notification);
							return true;
						/* Boot needs a real monitor; GiMock empties → 0. */
						case "get_n_monitors":
							this.reply_retval_i(request, 1);
							return true;
						case "get_monitor_geometry":
							this.reply_args_monitor_rect(request);
							return true;
						case "get_monitor_scale":
							this.reply_retval_f(request, 1.0f);
							return true;
						case "get_size":
							this.reply_args_size(request);
							return true;
						case "list_all_windows":
							this.reply_retval_empty_object_list(request);
							return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "Meta-Compositor":
					switch (name) {
						case "get_window_group":
							this.reply_retval_leased(request, boot.window_group);
							return true;
						case "get_top_window_group":
							this.reply_retval_leased(request, boot.top_window_group);
							return true;
						case "get_feedback_group":
							this.reply_retval_leased(request, boot.feedback_group);
							return true;
						case "get_laters":
							this.reply_retval_leased(request, boot.laters);
							return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "Meta-WorkspaceManager":
					switch (name) {
						case "get_n_workspaces":
							this.reply_retval_i(request, 1);
							return true;
						case "get_active_workspace":
						case "get_workspace_by_index":
							this.reply_retval_leased(request, boot.workspace);
							return true;
						case "get_layout_rows":
							this.reply_retval_i(request, -1);
							return true;
						case "get_layout_columns":
							this.reply_retval_i(request, 1);
							return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "Meta-Backend":
					switch (name) {
						case "get_stage":
							this.reply_retval_leased(request, boot.stage);
							return true;
						case "get_monitor_manager":
							this.reply_retval_leased(request, boot.monitor_manager);
							return true;
						case "is_rendering_hardware_accelerated":
							this.reply_retval_b(request, true);
							return true;
						/*
						 * Phase 4f: no BARRIERS → HotCorner fallback (enter-event)
						 * instead of Meta.Barrier construct path.
						 */
						case "get_capabilities":
							this.reply_retval_u(request, 0);
							return true;
						/*
						 * Override GiMock: shell expects null (no remote
						 * access). Design is GiMock mints even for nullable
						 * object returns; HelperMock may force null here.
						 */
						case "get_remote_access_controller":
							this.reply_void(request);
							return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "Meta-Context":
					switch (name) {
						case "get_backend":
							this.reply_retval_leased(request, boot.backend);
							return true;
						case "terminate":
							this.reply_void(request);
							GLib.Idle.add(() => {
								GLib.Process.exit(0);
								return GLib.Source.REMOVE;
							});
							return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "St-Settings":
					if (name == "get") {
						this.reply_retval_leased(request, boot.st_settings);
						return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "St-ThemeContext":
					switch (name) {
						case "get_for_stage":
							this.reply_retval_leased(request, boot.theme_context);
							return true;
						case "get_scale_factor":
							this.reply_retval_i(request, 1);
							return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "St-FocusManager":
					if (name == "get_for_stage") {
						this.reply_retval_leased(request, boot.focus_manager);
						return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				/* —— BackgroundImageCache cluster (phase 4a–4c) —— */
				case "Meta-BackgroundImageCache":
					switch (name) {
						case "get_default":
							this.reply_retval_leased(request, boot.background_image_cache);
							return true;
						case "load":
							this.reply_retval_leased(request,
								HelperMock.mint("Meta-BackgroundImage"));
							return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "Meta-BackgroundImage":
					if (name == "is_loaded") {
						/* GiMock bool empties → false; JS would wait on loaded. */
						this.reply_retval_b(request, true);
						return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				/* —— Helper-* (non-GIR) —— */
				case "Helper-Background":
					switch (name) {
						case "create":
							this.reply_args_lease(request, "Meta-Background");
							return true;
						case "set_file":
							this.reply_void(request);
							return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-BackgroundActor":
					if (name == "create") {
						this.reply_args_lease(request, "Meta-BackgroundActor");
						return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-Context":
					if (name == "terminate_with_error") {
						this.reply_void(request);
						return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-Settings":
					if (name == "get_ui_scaling_factor") {
						this.reply_retval_i(request, 1);
						return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-IdleMonitor":
					switch (name) {
						case "add_idle_watch":
						case "add_user_active_watch":
							this.reply_retval_u(request, 1);
							return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-Constraint":
					if (name == "create") {
						this.reply_args_lease(request, "Clutter-BindConstraint");
						return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-Display":
					switch (name) {
						case "add_keybinding":
							this.reply_retval_u(request, 1);
							return true;
						case "keybindings_set_custom_handler":
							this.reply_retval_b(request, true);
							return true;
						case "request_pad_osd":
							this.reply_void(request);
							return true;
						case "get_pad_button_label":
						case "get_pad_feature_label":
							this.reply_retval_s(request, "");
							return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-Window":
					switch (name) {
						case "foreach_transient":
						case "foreach_ancestor":
							this.reply_void(request);
							return true;
						case "begin_grab_op":
							this.reply_retval_b(request, true);
							return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-WindowActor":
					switch (name) {
						case "paint_to_content":
						case "get_image":
							this.reply_void(request);
							return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-SoundPlayer":
					switch (name) {
						case "play_from_file":
						case "play_from_theme":
							this.reply_void(request);
							return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-Selection":
					if (name == "transfer") {
						this.reply_args_bool(request, false);
						return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-SelectionSource":
					if (name == "read") {
						this.reply_args_bool(request, false);
						return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-SelectionSourceMemory":
					if (name == "create") {
						this.reply_retval_leased(request, HelperMock.mint("Meta-SelectionSource"));
						return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-ShapedTexture":
					if (name == "get_image") {
						this.reply_void(request);
						return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-ShaderEffect":
					if (name == "set_uniform") {
						this.reply_void(request);
						return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-GLSLEffect":
					switch (name) {
						case "create":
							this.reply_args_lease(request, "Shell-GLSLEffect");
							return true;
						case "add_glsl_snippet":
						case "set_uniform_float":
						case "set_uniform_matrix":
							this.reply_void(request);
							return true;
						case "get_uniform_location":
							this.reply_retval_i(request, -1);
							return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				case "Helper-ClutterThreads":
					if (name == "threads_add_repaint_func") {
						this.reply_retval_u(request, 1);
						return true;
					}
					/* Do not add here unless Helper-* / GiMock cannot answer. */
					break;

				/* —— OUT shapes GiMock does not pack —— */
				case "Clutter-PaintContext":
					if (name == "get_stage_view") {
						this.reply_args_lease_null(request);
						return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				/*
				 * Actor child walks: GiMock mints a new Actor for every
				 * nullable object return, so get_next_sibling never ends
				 * (ActorIter hang). One fake child, then null siblings.
				 * get_parent: track from add_child — mint forever walks to
				 * root; always-null breaks ScreenshotUI.close.
				 */
				case "Clutter-Actor":
					switch (name) {
						case "get_first_child":
						case "get_last_child":
							this.reply_retval_leased(request,
								HelperMock.mint("Clutter-Actor"));
							return true;
						case "get_next_sibling":
						case "get_previous_sibling":
							this.reply_void(request);
							return true;
						case "get_parent":
							{
								var child_id = (int) request.lease_id;
								if (child_id == this.orphan_parent_id) {
									this.reply_void(request);
									return true;
								}
								if (this.actor_parents.has_key(child_id)) {
									this.reply_retval_leased(request,
										this.actor_parents.get(child_id));
									return true;
								}
								if (this.orphan_parent == null) {
									this.orphan_parent =
										HelperMock.mint("Clutter-Actor");
									this.orphan_parent_id = (int)
										request.connection.export(
											this.orphan_parent);
								}
								this.reply_retval_leased(
									request, this.orphan_parent);
								return true;
							}
						case "add_child":
						case "insert_child_at_index":
						case "insert_child_above":
						case "insert_child_below":
							this.note_actor_parent(request);
							this.reply_void(request);
							return true;
						case "remove_child":
							this.clear_actor_parent(request);
							this.reply_void(request);
							return true;
						/* Singleton — GiMock would mint a new Context each call. */
						case "get_context":
							this.reply_retval_leased(request, boot.clutter_context);
							return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "Clutter-Context":
					/* Singleton Clutter.Backend (not Meta-Backend). */
					if (name == "get_backend") {
						this.reply_retval_leased(request, boot.clutter_backend);
						return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "Clutter-Backend":
					/* Singleton Seat — GiMock would mint a new one each call. */
					if (name == "get_default_seat") {
						this.reply_retval_leased(request, boot.clutter_seat);
						return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "Clutter-Seat":
					if (name == "get_context") {
						this.reply_retval_leased(request, boot.clutter_context);
						return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;

				case "Clutter-Stage":
					switch (name) {
						case "get_view_at":
							this.reply_args_lease_null(request);
							return true;
						case "paint_to_buffer":
							this.reply_args_empty_bytes(request);
							return true;
					}
					/* Do not add here unless GiMock is wrong (singleton, hang, or OUT shape). */
					return false;
			}

			if (prefix.has_prefix("Helper-")) {
				GLib.warning("HelperMock: unhandled %s — void reply", method);
				this.reply_void(request);
				return true;
			}
			/* Meta / Clutter / St unmatched → GiMock */
			return false;
		}

		/**
		 * Mint a fake lease for a wire alias via {@link OLLMrpc.GiMock.mint}.
		 */
		public static GLib.Object mint(string wire_alias)
		{
			try {
				return OLLMrpc.GiMock.mint(wire_alias);
			} catch (GLib.Error e) {
				GLib.error("HelperMock: %s", e.message);
			}
		}

		private void note_actor_parent(OLLMrpc.Request request)
		{
			if (request.args.size < 1) {
				return;
			}
			var child_obj = request.args.get(0).get_object();
			if (child_obj == null) {
				return;
			}
			var parent_id = (int) request.lease_id;
			if (parent_id == 0 || !request.connection.leases.has_key(parent_id)) {
				return;
			}
			/*
			 * Prefer Handle.rpc_lid (wire id). export() on a decode-time
			 * proxy would mint a second lease and miss get_parent's id.
			 */
			var child_id = 0;
			var live = child_obj as OLLMrpc.Live.Handle;
			if (live != null && live.rpc_lid != 0) {
				child_id = (int) live.rpc_lid;
			} else {
				child_id = (int) request.connection.export(child_obj);
			}
			if (child_id == 0) {
				return;
			}
			this.actor_parents.set(
				child_id, request.connection.leases.get(parent_id));
		}

		private void clear_actor_parent(OLLMrpc.Request request)
		{
			if (request.args.size < 1) {
				return;
			}
			var child_obj = request.args.get(0).get_object();
			if (child_obj == null) {
				return;
			}
			var live = child_obj as OLLMrpc.Live.Handle;
			var child_id = (live != null && live.rpc_lid != 0)
				? (int) live.rpc_lid
				: (int) request.connection.export(child_obj);
			this.actor_parents.unset(child_id);
		}

		private void reply_void(OLLMrpc.Request request)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
			});
		}

		private void reply_retval_i(OLLMrpc.Request request, int value)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("i", value),
			});
		}

		private void reply_retval_u(OLLMrpc.Request request, uint value)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("u", value),
			});
		}

		private void reply_retval_b(OLLMrpc.Request request, bool value)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("b", value),
			});
		}

		private void reply_retval_f(OLLMrpc.Request request, float value)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("f", value),
			});
		}

		private void reply_retval_s(OLLMrpc.Request request, string value)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("s", value),
			});
		}

		private void reply_retval_empty_object_list(OLLMrpc.Request request)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", new Gee.ArrayList<GLib.Object>()),
			});
		}

		private void reply_args_monitor_rect(OLLMrpc.Request request)
		{
			int[] rect = {
				0,
				0,
				MockBootGraph.SCREEN_WIDTH,
				MockBootGraph.SCREEN_HEIGHT,
			};
			uint8[] data = new uint8[sizeof(int) * 4];
			Memory.copy(data, rect, data.length);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("ay", new GLib.Bytes(data)),
			});
		}

		private void reply_args_size(OLLMrpc.Request request)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args(
					"ii",
					MockBootGraph.SCREEN_WIDTH,
					MockBootGraph.SCREEN_HEIGHT
				),
			});
		}

		private void reply_args_lease(
			OLLMrpc.Request request,
			string wire_alias
		) {
			var handle = (uint64) request.connection.export(
				HelperMock.mint(wire_alias)
			);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", handle),
			});
		}

		private void reply_args_lease_null(OLLMrpc.Request request)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("t", (uint64) 0),
			});
		}

		private void reply_retval_leased(
			OLLMrpc.Request request,
			GLib.Object obj
		) {
			request.connection.export(obj);
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("o", obj),
			});
		}

		private void reply_args_bool(OLLMrpc.Request request, bool ok)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("b", ok),
			});
		}

		private void reply_args_empty_bytes(OLLMrpc.Request request)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				args = OLLMrpc.args("ay", new GLib.Bytes(new uint8[0])),
			});
		}
	}
}
