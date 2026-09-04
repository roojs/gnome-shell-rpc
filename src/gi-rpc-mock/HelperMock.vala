namespace GnomeShellRpc.GiRpcMock
{
	/**
	 * Bulk mock for Helper wires plus early Meta boot getters.
	 *
	 * Return false for unhandled GI calls so libocrpc {@link GiMock} runs.
	 */
	public class HelperMock : GLib.Object, OLLMrpc.MockDispatch
	{
		public bool dispatch(OLLMrpc.Request request)
		{
			if (!HelperMock.is_mock_wire(request.method)) {
				return false;
			}

			var dot = request.method.index_of_char('.');
			var prefix = request.method.substring(0, dot);
			var method = request.method.substring(dot + 1);

			var boot = MockBootGraph.get();

			switch (prefix) {
				case "Meta-Display":
					switch (method) {
						case "get_context":
							this.reply_retval_leased(request, boot.context);
							return true;

						case "get_compositor":
							this.reply_retval_leased(request, boot.compositor);
							return true;
					}
					break;

				case "Meta-Context":
					switch (method) {
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
					break;

				case "Meta-Backend":
					if (method == "get_stage") {
						this.reply_retval_leased(request, boot.stage);
						return true;
					}
					break;

				case "Helper-Background":
					switch (method) {
						case "create":
							this.reply_args_lease(request, "Meta-Background");
							return true;

						case "set_file":
							this.reply_void(request);
							return true;
					}
					break;

				case "Helper-BackgroundActor":
					if (method == "create") {
						this.reply_args_lease(request, "Meta-BackgroundActor");
						return true;
					}
					break;

				case "Helper-Context":
					if (method == "terminate_with_error") {
						this.reply_void(request);
						return true;
					}
					break;

				case "Helper-Settings":
					if (method == "get_ui_scaling_factor") {
						this.reply_retval_i(request, 1);
						return true;
					}
					break;

				case "Helper-IdleMonitor":
					switch (method) {
						case "add_idle_watch":
						case "add_user_active_watch":
							this.reply_retval_u(request, 1);
							return true;
					}
					break;

				case "Helper-Display":
					switch (method) {
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
					break;

				case "Helper-Window":
					switch (method) {
						case "foreach_transient":
						case "foreach_ancestor":
							this.reply_void(request);
							return true;

						case "begin_grab_op":
							this.reply_retval_b(request, true);
							return true;
					}
					break;

				case "Helper-WindowActor":
					switch (method) {
						case "paint_to_content":
						case "get_image":
							this.reply_void(request);
							return true;
					}
					break;

				case "Helper-SoundPlayer":
					switch (method) {
						case "play_from_file":
						case "play_from_theme":
							this.reply_void(request);
							return true;
					}
					break;

				case "Helper-Selection":
					if (method == "transfer") {
						this.reply_args_bool(request, false);
						return true;
					}
					break;

				case "Helper-SelectionSource":
					if (method == "read") {
						this.reply_args_bool(request, false);
						return true;
					}
					break;

				case "Helper-SelectionSourceMemory":
					if (method == "create") {
						this.reply_retval_object(request, "Meta-SelectionSource");
						return true;
					}
					break;

				case "Helper-ShapedTexture":
					if (method == "get_image") {
						this.reply_void(request);
						return true;
					}
					break;

				case "Helper-ShaderEffect":
					if (method == "set_uniform") {
						this.reply_void(request);
						return true;
					}
					break;

				case "Helper-GLSLEffect":
					switch (method) {
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
					break;

				case "Helper-ClutterThreads":
					if (method == "threads_add_repaint_func") {
						this.reply_retval_u(request, 1);
						return true;
					}
					break;

				case "Clutter-PaintContext":
					if (method == "get_stage_view") {
						this.reply_args_lease_null(request);
						return true;
					}
					break;

				case "Clutter-Stage":
					switch (method) {
						case "get_view_at":
							this.reply_args_lease_null(request);
							return true;

						case "paint_to_buffer":
							this.reply_args_empty_bytes(request);
							return true;
					}
					break;
			}

			GLib.warning("HelperMock: unhandled %s — void reply",
				request.method);
			this.reply_void(request);
			return true;
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

		private static bool is_mock_wire(string method)
		{
			return method.has_prefix("Helper-")
				|| method.has_prefix("Meta-Display.")
				|| method.has_prefix("Meta-Context.")
				|| method.has_prefix("Meta-Backend.")
				|| method.has_prefix("Clutter-PaintContext.")
				|| method.has_prefix("Clutter-Stage.");
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

		private void reply_retval_s(OLLMrpc.Request request, string value)
		{
			request.reply(new OLLMrpc.Response() {
				id = request.id,
				retval = OLLMrpc.val("s", value),
			});
		}

		private void reply_args_lease(
			OLLMrpc.Request request,
			string wire_alias
		) {
			var handle = HelperMock.export_new(request, wire_alias);
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

		private void reply_retval_object(
			OLLMrpc.Request request,
			string wire_alias
		) {
			this.reply_retval_leased(request, HelperMock.mint(wire_alias));
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

		private static uint64 export_new(
			OLLMrpc.Request request,
			string wire_alias
		) {
			return (uint64) request.connection.export(
				HelperMock.mint(wire_alias)
			);
		}
	}
}
