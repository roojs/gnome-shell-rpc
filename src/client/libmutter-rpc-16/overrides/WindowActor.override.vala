		/**
		 * Set by {@link Window.get_compositor_private} on the overview
		 * stand-in. A leased window actor leaves this unset and the
		 * getter calls the server.
		 */
		internal Window? bound_meta_window;

		public Window? meta_window {
			[CCode (cname = "meta_window_actor_get_meta_window")]
			get {
				if (this.bound_meta_window != null) {
					return this.bound_meta_window;
				}
				var response = Gsr.Client.Rpc.call_value(
					"Meta-WindowActor.get_meta_window", this);
				if (response.retval.type() == GLib.Type.INVALID) {
					return null;
				}
				return (Window) response.retval.get_object();
			}
		}

		public Clutter.Content? paint_to_content(Mtk.Rectangle? clip) throws GLib.Error
		{
			var has_clip = clip != null;
			var clip_x = 0, clip_y = 0, clip_width = 0, clip_height = 0;
			if (has_clip) {
				clip_x = clip.x;
				clip_y = clip.y;
				clip_width = clip.width;
				clip_height = clip.height;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-WindowActor.paint_to_content", this,
				OLLMrpc.args("biiii", has_clip, clip_x, clip_y,
					clip_width, clip_height));
			if (response.args.size < 3 || response.buffer == null
					|| response.buffer.fd < 0) {
				return null;
			}
			var width = response.args.get(0).get_int();
			var height = response.args.get(1).get_int();
			var stride = response.args.get(2).get_int();
			var nbytes = stride * height;
			var pixels = new uint8[nbytes];
			var fd = response.buffer.fd;
			Posix.lseek(fd, 0, Posix.SEEK_SET);
			var got = 0;
			while (got < nbytes) {
				var n = Posix.read(fd, (void*) &pixels[got], nbytes - got);
				if (n <= 0) {
					break;
				}
				got += (int) n;
			}
			if (got < nbytes) {
				return null;
			}
			return new Gsr.Client.Rpc.PaintedContent(
				width, height, stride, (owned) pixels);
		}

		/**
		 * Stock {@code meta_window_actor_get_image}. ARGB32 pixels on buffer
		 * → local {@link Cairo.ImageSurface}.
		 */
		public Cairo.Surface? get_image(Mtk.Rectangle? clip)
		{
			var has_clip = clip != null;
			var clip_x = 0, clip_y = 0, clip_width = 0, clip_height = 0;
			if (has_clip) {
				clip_x = clip.x;
				clip_y = clip.y;
				clip_width = clip.width;
				clip_height = clip.height;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-Mutter-WindowActor.get_image", this,
				OLLMrpc.args("biiii", has_clip, clip_x, clip_y,
					clip_width, clip_height));
			if (response.args.size < 3 || response.buffer == null
					|| response.buffer.fd < 0) {
				return null;
			}
			var width = response.args.get(0).get_int();
			var height = response.args.get(1).get_int();
			var stride = response.args.get(2).get_int();
			var nbytes = stride * height;
			var pixels = new uint8[nbytes];
			var fd = response.buffer.fd;
			Posix.lseek(fd, 0, Posix.SEEK_SET);
			var got = 0;
			while (got < nbytes) {
				var n = Posix.read(fd, (void*) &pixels[got], nbytes - got);
				if (n <= 0) {
					break;
				}
				got += (int) n;
			}
			if (got < nbytes) {
				return null;
			}
			return new Cairo.ImageSurface.for_data(
				(owned) pixels, Cairo.Format.ARGB32, width, height, stride);
		}
