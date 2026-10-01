		/**
		 * Setters store locally and RPC only after {@code rpc_lid} is set.
		 * A generated setter would run while GJS constructs the object.
		 */
		public Background? background {
			get { return this.priv_background; }
			set {
				this.priv_background = value;
				if (this.rpc_lid != 0 && value != null) {
					Gsr.Client.Rpc.call_value("Meta-BackgroundContent.set_background", this, OLLMrpc.args("o", value));
				}
			}
		}

		public bool vignette {
			get { return this.priv_vignette; }
			set {
				this.priv_vignette = value;
				this.push_vignette();
			}
		}

		public double vignette_sharpness {
			get { return this.priv_vignette_sharpness; }
			set {
				this.priv_vignette_sharpness = value;
				this.push_vignette();
			}
		}

		public double brightness {
			get { return this.priv_brightness; }
			set {
				this.priv_brightness = value;
				this.push_vignette();
			}
		}

		public float rounded_clip_radius {
			get { return this.priv_rounded_clip_radius; }
			set {
				this.priv_rounded_clip_radius = value;
				if (this.rpc_lid != 0) {
					Gsr.Client.Rpc.call_value("Meta-BackgroundContent.set_rounded_clip_radius", this, OLLMrpc.args("f", (double) value));
				}
			}
		}

		Background? priv_background;
		bool priv_vignette;
		double priv_vignette_sharpness = 0.5;
		double priv_brightness = 1.0;
		float priv_rounded_clip_radius = 0.0f;

		/**
		 * BackgroundActor attaches this after the lease exists.
		 * Stock {@code new} is the static method; its C name is taken.
		 */
		[CCode (cname = "gsr_meta_background_content_blank")]
		public BackgroundContent()
		{
			Object();
		}

		public void set_rounded_clip_bounds(Graphene.Rect? bounds)
		{
			if (this.rpc_lid == 0) {
				return;
			}
			if (bounds == null) {
				Gsr.Client.Rpc.call_value("Meta-BackgroundContent.set_rounded_clip_bounds", this, OLLMrpc.args("ay", new GLib.Bytes(new uint8[0])));
				return;
			}
			uint8[] data = new uint8[sizeof(Graphene.Rect)];
			*((Graphene.Rect*) data) = bounds;
			Gsr.Client.Rpc.call_value("Meta-BackgroundContent.set_rounded_clip_bounds", this, OLLMrpc.args("ay", new GLib.Bytes(data)));
		}

		void push_vignette()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			Gsr.Client.Rpc.call_value("Meta-BackgroundContent.set_vignette", this, OLLMrpc.args("bdd", this.priv_vignette, this.priv_brightness, this.priv_vignette_sharpness));
		}

		/*
		 * Vala requires these because the class implements Clutter.Content.
		 * visible=false is introspectable=0 in a GIR valac writes.
		 * GJS loads stock Clutter-16: paint_content has no invoker.
		 * attached and detached are signals. get_preferred_size, invalidate,
		 * and invalidate_size stay callable on every Content.
		 */
		[GIR (visible = false)]
		public bool get_preferred_size(out float width, out float height)
		{
			width = 0;
			height = 0;
			GLib.error("Meta.BackgroundContent.get_preferred_size");
			return false;
		}

		[GIR (visible = false)]
		public void paint_content(Clutter.Actor actor, Clutter.PaintNode node, Clutter.PaintContext paint_context)
		{
			GLib.error("Meta.BackgroundContent.paint_content");
		}

		[GIR (visible = false)]
		public void attached(Clutter.Actor actor)
		{
			GLib.error("Meta.BackgroundContent.attached");
		}

		[GIR (visible = false)]
		public void detached(Clutter.Actor actor)
		{
			GLib.error("Meta.BackgroundContent.detached");
		}

		[GIR (visible = false)]
		public void invalidate()
		{
			GLib.error("Meta.BackgroundContent.invalidate");
		}

		[GIR (visible = false)]
		public void invalidate_size()
		{
			GLib.error("Meta.BackgroundContent.invalidate_size");
		}
