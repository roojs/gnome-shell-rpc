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

		construct {
			if (this.rpc_lid == 0) {
				var subclass = this is DrawingArea
					&& this.get_type() != typeof(DrawingArea);
				this.open_drawing_area_lease(subclass);
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
