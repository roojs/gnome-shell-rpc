		/**
		 * Stock {@code st_spinner_content_new} on the compositor.
		 * {@code new St.SpinnerContent()} from the shell leases that
		 * peer. A decode of the create reply already has
		 * {@code rpc_lid} and must not create another.
		 */
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-SpinnerContent.create", null);
			if (response.retval.type() == GLib.Type.INVALID
					|| response.retval.get_object() == null) {
				return;
			}
			var peer = response.retval.get_object() as OLLMrpc.Live.Interface;
			if (peer == null || peer.rpc_lid == 0) {
				return;
			}
			this.rpc_lid = peer.rpc_lid;
			Gsr.Client.Rpc.register_handle(this);
		}

		/**
		 * {@link Clutter.Content.get_preferred_size} on the leased
		 * {@code StSpinnerContent}.
		 */
		public bool get_preferred_size(out float width, out float height)
		{
			width = 0;
			height = 0;
			if (this.rpc_lid == 0) {
				return false;
			}
			var response = Gsr.Client.Rpc.call_value(
				"Gsr-St-SpinnerContent.get_preferred_size", this);
			if (response.args.size < 2) {
				return false;
			}
			width = (float) response.args.get(0).get_double();
			height = (float) response.args.get(1).get_double();
			return response.retval.get_boolean();
		}

		/**
		 * Paint runs on the leased spinner after
		 * {@link Clutter.Actor.set_content}. There is no client stage.
		 */
		public void paint_content(
			Clutter.Actor actor,
			Clutter.PaintNode node,
			Clutter.PaintContext paint_context
		) {
			return;
		}

		/**
		 * Stock leaves this vfunc unset. Attach is
		 * {@link Clutter.Actor.set_content} of the leased spinner.
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

		/**
		 * {@code clutter_content_invalidate} on the leased spinner.
		 */
		public void invalidate()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			Gsr.Client.Rpc.call_value("Gsr-St-SpinnerContent.invalidate", this);
		}

		/**
		 * {@code clutter_content_invalidate_size} on the leased spinner.
		 */
		public void invalidate_size()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			Gsr.Client.Rpc.call_value(
				"Gsr-St-SpinnerContent.invalidate_size", this);
		}
