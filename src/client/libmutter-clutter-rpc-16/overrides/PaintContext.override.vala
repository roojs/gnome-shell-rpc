		/* Not in typelib (introspectable=0) — St still links these. */
		public PaintContext.for_framebuffer(
			Cogl.Framebuffer framebuffer,
			Mtk.Region redraw_clip,
			PaintFlag paint_flags,
			ColorState color_state
		) {
			Object();
			GLib.error("gi-stub: Clutter-PaintContext.new_for_framebuffer not wired");
		}

		public ColorState get_color_state()
		{
			GLib.error("gi-stub: Clutter-PaintContext.get_color_state not wired");
			return null;
		}

		/**
		 * Not in the typelib. Reply is a lease id in args[0].
		 */
		[CCode (cname = "clutter_paint_context_get_stage_view")]
		public StageView? get_stage_view()
		{
			try {
				var response = Gsr.call_value("Clutter-PaintContext.get_stage_view", this);
				if (response.args.size == 0) {
					return null;
				}
				var handle = response.args.get(0).get_uint64();
				if (handle == 0) {
					return null;
				}
				var view = new StageView();
				view.rpc_lid = handle;
				return view;
			} catch (GLib.Error e) {
				GLib.warning("get_stage_view: %s", e.message);
				return null;
			}
		}
