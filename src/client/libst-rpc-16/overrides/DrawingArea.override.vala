		/**
		 * Stock {@code st_drawing_area_get_context} — {@code cairo_t *} is
		 * not on the object wire. GJS {@code repaint} handlers call this
		 * and {@code cr.$dispose()}. Local {@link Cairo.ImageSurface} of
		 * {@link get_surface_size}; pixels stay on the client.
		 */
		public Cairo.Context get_context()
		{
			uint32 width = 0;
			uint32 height = 0;
			this.get_surface_size(out width, out height);
			var w = (int) width;
			var h = (int) height;
			if (w < 1) {
				w = 1;
			}
			if (h < 1) {
				h = 1;
			}
			var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, w, h);
			return new Cairo.Context(surface);
		}
