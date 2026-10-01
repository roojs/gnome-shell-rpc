	/**
	 * Event is Compact — not on the wire. Stock looks up key-focus for
	 * key/IM events, otherwise the actor under the event coords
	 * ({@link get_actor_at_pos} REACTIVE) at call time.
	 */
	[CCode (cname = "clutter_stage_get_event_actor")]
	public Actor? get_event_actor(Event event)
	{
		var type = event.type();
		if (type == EventType.key_press
				|| type == EventType.key_release
				|| type == EventType.im_commit
				|| type == EventType.im_delete
				|| type == EventType.im_preedit) {
			return this.key_focus;
		}
		float x = 0.0f, y = 0.0f;
		event.get_coords(out x, out y);
		return this.get_actor_at_pos(PickMode.reactive, x, y);
	}

	/**
	 * Not in the typelib. Reply is a lease id in args[0].
	 */
	[CCode (cname = "clutter_stage_get_view_at")]
	public StageView? get_view_at(float x, float y)
	{
		try {
			var response = Gsr.call_value("Clutter-Stage.get_view_at", this, OLLMrpc.args("ff", x, y));
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
			GLib.warning("get_view_at: %s", e.message);
			return null;
		}
	}

	/**
	 * Caller buffer has no length, so the generator skips it. Pixels come
	 * back as {@link GLib.Bytes} in args[0].
	 */
	[CCode (cname = "clutter_stage_paint_to_buffer")]
	public bool paint_to_buffer(
		Mtk.Rectangle rect,
		float scale,
		[CCode (array_length = false)] uint8[] data,
		int stride,
		Cogl.PixelFormat format,
		PaintFlag paint_flags
	) throws GLib.Error {
		var image_height = (int) Math.ceilf(rect.height * scale);
		if (image_height < 1) {
			image_height = 1;
		}
		var n_bytes = stride * image_height;
		var response = Gsr.call_value("Clutter-Stage.paint_to_buffer", this, OLLMrpc.args(
			"iiiifiiuu",
			rect.x, rect.y, rect.width, rect.height, scale,
			n_bytes, stride, (uint) format, (uint) paint_flags));
		if (response.args.size == 0) {
			throw new GLib.IOError.FAILED("paint_to_buffer: empty reply");
		}
		var bytes = (GLib.Bytes) response.args.get(0).get_boxed();
		var pixels = bytes.get_data();
		var n = int.min(n_bytes, pixels.length);
		GLib.Memory.copy(data, pixels, n);
		return true;
	}
