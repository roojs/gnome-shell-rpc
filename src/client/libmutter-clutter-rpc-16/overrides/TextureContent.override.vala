		/*
		 * Vala requires these because the class implements Clutter.Content
		 * (paint snapshots decoded from the server must fit a Content
		 * GValue). Same shape as BackgroundContent.override: hidden from
		 * introspection, unreachable by design — painting runs on the
		 * server-side texture, never through this stub.
		 */
		[GIR (visible = false)]
		public bool get_preferred_size(out float width, out float height)
		{
			width = 0;
			height = 0;
			GLib.error("Clutter.TextureContent.get_preferred_size should never be called");
			return false;
		}

		[GIR (visible = false)]
		public void paint_content(
			Clutter.Actor actor, 
			Clutter.PaintNode node, 
			Clutter.PaintContext paint_context
		) {
			GLib.error("Clutter.TextureContent.paint_content should never be called");
		}

		[GIR (visible = false)]
		public void attached(Clutter.Actor actor)
		{
			GLib.error("Clutter.TextureContent.attached should never be called");
		}

		[GIR (visible = false)]
		public void detached(Clutter.Actor actor)
		{
			GLib.error("Clutter.TextureContent.detached should never be called");
		}

		[GIR (visible = false)]
		public void invalidate()
		{
			GLib.error("Clutter.TextureContent.invalidate should never be called");
		}

		[GIR (visible = false)]
		public void invalidate_size()
		{
			GLib.error("Clutter.TextureContent.invalidate_size should never be called");
		}
