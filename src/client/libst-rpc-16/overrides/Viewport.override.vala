		/**
		 * Exact viewport uses {@code St-Viewport.new}.
		 * A subclass leases {@code ViewportActor}.
		 * The base arm subscribes signals and does not mint again.
		 */
		public override void rpc_construct()
		{
			if (this.rpc_lid != 0) {
				base.rpc_construct();
				return;
			}
			var t = this.get_type();
			while (t != GLib.Type.INVALID && t != typeof(Viewport)) {
				if (OLLMrpc.Bin.gtype_to_alias != null
						&& OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
					base.rpc_construct();
					return;
				}
				t = t.parent();
			}
			if (this.get_type() == typeof(Viewport)) {
				base.rpc_construct();
				return;
			}
			this.create_viewport();
			base.rpc_construct();
		}

		/* Row 12 bisect: fieldless property stubs. */
		public Adjustment hadjustment {
			get { return null; }
			set { }
		}

		public Adjustment vadjustment {
			get { return null; }
			set { }
		}

		public void get_adjustments(out Adjustment hadjustment, out Adjustment vadjustment)
		{
			hadjustment = null;
			vadjustment = null;
		}

		public void set_adjustments(Adjustment hadjustment, Adjustment vadjustment)
		{
		}
