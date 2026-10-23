		Cairo.ImageSurface? repaint_surface;

		/**
		 * One local surface per emission. A second {@code get_context}
		 * in the same {@code vfunc_repaint} draws on that surface.
		 * {@link send_repaint_pixels} clears it.
		 */
		public Cairo.Context get_context()
		{
			if (this.repaint_surface != null) {
				return new Cairo.Context(this.repaint_surface);
			}
			uint32 width = 0;
			uint32 height = 0;
			this.get_surface_size(out width, out height);
			var w = ((int) width).clamp(1, int.MAX);
			var h = ((int) height).clamp(1, int.MAX);
			this.repaint_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, w, h);
			return new Cairo.Context(this.repaint_surface);
		}

		/**
		 * Stock {@code queue_repaint} emits before it returns. The
		 * server method ignores a call that arrives during that emission.
		 */
		public void queue_repaint()
		{
			Gsr.Client.Rpc.call_value("Gsr-St-DrawingArea.queue_repaint", this);
		}

		/**
		 * Exact type uses {@code St-DrawingArea.new}.
		 * A subclass uses the drawing-area peer.
		 */
		void open_drawing_area_lease(bool subclass)
		{
			if (subclass) {
				this.create_drawing_area();
				return;
			}
			var response = Gsr.Client.Rpc.call_value("St-DrawingArea.new");
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
		}

		/**
		 * Peer is {@link Gsr.Server.St.DrawingAreaActor}, not a plain
		 * {@code StDrawingArea}. Preferred-size vfuncs are hooked so a
		 * slider's JS height is the allocation. Repaint stays the
		 * stock allocate emission.
		 */
		void create_drawing_area()
		{
			Gsr.Client.Rpc.hook_rows = new Gee.ArrayList<Gsr.Client.Rpc.InvokeRow>();
			var overridden = Gsr.Client.Rpc.VfuncRelay.overridden(
				this.get_type(), "Clutter", "Actor", "StWidget", new string[0]);
			string[] names = {};
			var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
			foreach (var name in overridden) {
				if (name != "get_preferred_width" && name != "get_preferred_height") {
					continue;
				}
				var vfunc_id = -1;
				var hook_id = this.bind_vfunc(name, out vfunc_id);
				if (hook_id == 0) {
					continue;
				}
				names += name;
				vfunc_ids.add("i", vfunc_id);
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-DrawingArea.create", null,
				OLLMrpc.args("s", this.get_type().name()));
			this.rpc_lid = response.args.get(0).get_uint64();
			Gsr.Client.Rpc.register_handle(this);
			if (names.length == 0) {
				Gsr.Client.Rpc.hook_rows = null;
				return;
			}
			var hooks = Gsr.Client.Rpc.call_value(
				"Gsr-St-DrawingArea.add_hooks", this,
				OLLMrpc.args("Sv", names, vfunc_ids.end()));
			var ids = hooks.args.get(0).get_variant();
			if (Gsr.Client.Rpc.handlers == null) {
				Gsr.Client.Rpc.handlers = new Gee.HashMap<int, Gsr.Client.Rpc.InvokeRow>();
			}
			var n = (int) ids.n_children();
			for (var i = 0; i < n; i++) {
				Gsr.Client.Rpc.handlers.set(
					(int) ids.get_child_value(i).get_uint64(),
					Gsr.Client.Rpc.hook_rows.get(i));
			}
			Gsr.Client.Rpc.hook_rows = null;
		}

		/**
		 * Exact type uses {@code St-DrawingArea.new}.
		 * A subclass uses the drawing-area peer.
		 */
		public override void rpc_construct()
		{
			var subclass = this is DrawingArea
				&& this.get_type() != typeof(DrawingArea);
			this.open_drawing_area_lease(subclass);
		}

		construct {
			if (this.rpc_lid == 0) {
				var subclass = this is DrawingArea
					&& this.get_type() != typeof(DrawingArea);
				this.open_drawing_area_lease(subclass);
				if (this.rpc_lid != 0) {
					this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
					this.prop_batch_open = true;
				}
			}
			if (this.rpc_lid == 0 || this.get_type() == typeof(DrawingArea)) {
				return;
			}
			if (OLLMrpc.Gi.vfunc_slot(this.get_type(), "St", "DrawingArea", "repaint")
					== OLLMrpc.Gi.vfunc_slot(typeof(DrawingArea), "St", "DrawingArea", "repaint")) {
				return;
			}
			var hook_id = Gsr.Client.Rpc.callback_bind((call) => {
				Gsr.Client.Rpc.vfunc_call_void(
					this, OLLMrpc.Gi.vfunc_offset("St", "DrawingArea", "repaint"));
				this.send_repaint_pixels();
				return null;
			});
			Gsr.Client.Rpc.call_value(
				"Gsr-St-DrawingArea.watch_repaint", this,
				OLLMrpc.args("t", hook_id));
		}

		/**
		 * After {@code vfunc_repaint}. Nested {@code Gsr-St-DrawingArea.paint}
		 * while the server is still inside the emission.
		 */
		void send_repaint_pixels()
		{
			var surface = this.repaint_surface;
			this.repaint_surface = null;
			if (surface == null) {
				return;
			}
			surface.flush();
			var width = surface.get_width();
			var height = surface.get_height();
			var stride = surface.get_stride();
			if (width < 1 || height < 1 || stride < 1) {
				return;
			}
			var nbytes = stride * height;
			var fd = Linux.memfd_create("gsr-repaint", Linux.MemfdFlags.CLOEXEC);
			if (fd < 0) {
				return;
			}
			unowned uint8* pixels = (uint8*) surface.get_data();
			if (Posix.write(fd, pixels, (size_t) nbytes) != nbytes) {
				Posix.close(fd);
				return;
			}
			Posix.lseek(fd, 0, Posix.SEEK_SET);
			Gsr.Client.Rpc.call_value(
				"Gsr-St-DrawingArea.paint", this,
				OLLMrpc.args("uuux", (uint) width, (uint) height,
					(uint) stride, (int64) nbytes),
				new OLLMrpc.Live.Buffer(fd));
		}
