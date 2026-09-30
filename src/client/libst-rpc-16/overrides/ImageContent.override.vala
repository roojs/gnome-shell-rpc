		[CCode (cname = "memfd_create", cheader_filename = "sys/mman.h")]
		private static extern int memfd_create(string name, uint flags);

		public static Clutter.Content new_with_preferred_size(int32 width, int32 height)
		{
			var response = GnomeShellRpc.call_value(
				"Helper-ImageContent.create",
				null,
				OLLMrpc.args("ii", width, height));
			var obj = (ImageContent) response.retval.get_object();
			GnomeShellRpc.GiStub.Runtime.register_handle(obj);
			return obj;
		}

		/**
		 * Stock {@code st_image_content_set_data} — pixels on
		 * {@link OLLMrpc.Request.buffer} (memfd). Compositor Cogl context
		 * is local; {@code cogl_context} is GIR-shaped only.
		 */
		public new bool set_data(
			Cogl.Context cogl_context,
			uint8[] data,
			Cogl.PixelFormat pixel_format,
			uint width,
			uint height,
			uint row_stride
		) throws GLib.Error {
			var nbytes = data.length;
			var fd = memfd_create("gsr-img", 1);
			if (fd < 0 || Posix.write(fd, data, nbytes) != nbytes) {
				if (fd >= 0) {
					Posix.close(fd);
				}
				throw new GLib.IOError.FAILED("ImageContent.set_data memfd");
			}
			Posix.lseek(fd, 0, Posix.SEEK_SET);
			var response = GnomeShellRpc.call_value(
				"Helper-ImageContent.set_data", this,
				OLLMrpc.args("uuuux", (uint) pixel_format, width, height,
					row_stride, (int64) nbytes),
				new OLLMrpc.Live.Buffer(fd));
			return response.retval.get_boolean();
		}

		/**
		 * {@link Clutter.Content.get_preferred_size} — peer
		 * {@code st_image_content_get_preferred_size}.
		 */
		public bool get_preferred_size(out float width, out float height)
		{
			var response = GnomeShellRpc.call_value(
				"Clutter-Content.get_preferred_size", this);
			width = (float) response.args.get(0).get_float();
			height = (float) response.args.get(1).get_float();
			return response.retval.get_boolean();
		}

		/**
		 * {@link Clutter.Content.invalidate} on the leased peer.
		 */
		public void invalidate()
		{
			GnomeShellRpc.call_value("Clutter-Content.invalidate", this);
		}

		/**
		 * {@link Clutter.Content.invalidate_size} on the leased peer.
		 */
		public void invalidate_size()
		{
			GnomeShellRpc.call_value("Clutter-Content.invalidate_size", this);
		}

		/**
		 * Stock {@code st_image_content_paint_content} — Cogl texture
		 * node on the compositor. No public {@code clutter_content_paint};
		 * {@link Clutter.Actor.set_content} attaches the peer and paint
		 * runs there. Client stage does not paint this content.
		 */
		public void paint_content(
			Clutter.Actor actor,
			Clutter.PaintNode node,
			Clutter.PaintContext paint_context
		) {
			return;
		}

		/**
		 * Stock leaves this vfunc unset. Attach is peer
		 * {@link Clutter.Actor.set_content}.
		 */
		public void attached(Clutter.Actor actor)
		{
			return;
		}

		/**
		 * Stock leaves this vfunc unset.
		 */
		public void detached(Clutter.Actor actor)
		{
			return;
		}
