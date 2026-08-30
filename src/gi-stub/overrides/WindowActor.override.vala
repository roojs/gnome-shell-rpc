		public void show()
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.show", this);
		}

		public void hide()
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.hide", this);
		}

		public bool get_visible()
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.is_visible", this);
			return response.retval.get_boolean();
		}

		public new void set_position(float x, float y)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.set_position",
				this,
				OLLMrpc.args("ff", x, y));
		}

		public new void set_size(float width, float height)
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.set_size",
				this,
				OLLMrpc.args("ff", width, height));
		}

		public new void get_position(out float x, out float y)
		{
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.get_position", this);
			x = (float) response.args.get(0).get_float();
			y = (float) response.args.get(1).get_float();
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
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-WindowActor.paint_to_content", this,
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
			return new GnomeShellRpc.GiStub.PaintedContent(
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
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-WindowActor.get_image", this,
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
