		/**
		 * Exact viewport uses {@code St-Viewport.new}.
		 * A subclass leases {@code ViewportActor}.
		 * Actor's constructor opens the property batch.
		 */
		public override void rpc_construct()
		{
			this.create_viewport(false);
		}

		/**
		 * JavaScript subclasses leave {@code rpc_lid} at 0.
		 * This constructor still runs for them.
		 */
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			this.create_viewport(true);
		}

		/**
		 * GJS {@code St.Viewport} subclass. Peer is
		 * {@link Gsr.Server.St.ViewportActor}. Only {@code allocate}
		 * is hooked. {@code helper_attached} stays false.
		 *
		 * {@code batch} subscribes signals and opens the property
		 * batch. The constructor passes true.
		 */
		void create_viewport(bool batch)
		{
			var stock = this.get_type() == typeof(Viewport);
			var t = this.get_type();
			while (!stock && t != GLib.Type.INVALID && t != typeof(Viewport)) {
				if (OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
					stock = true;
					break;
				}
				t = t.parent();
			}
			if (stock) {
				base.rpc_construct();
				if (!batch || this.rpc_lid == 0) {
					return;
				}
				this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
				this.prop_batch_open = true;
				return;
			}
			Gsr.Client.Rpc.hook_rows = new Gee.ArrayList<Gsr.Client.Rpc.InvokeRow>();
			var overridden = Gsr.Client.Rpc.VfuncRelay.overridden(this.get_type(), 
				"Clutter", "Actor", "StWidget", new string[0]);
				
			string[] names = {};
			var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
			foreach (var name in overridden) {
				if (name != "allocate") {
					continue;
				}
				var vfunc_id = -1;
				var hook_id = this.bind_vfunc(name, out vfunc_id);
				if (hook_id == 0) {
					continue;
				}
				names += name;
				vfunc_ids.add("i", vfunc_id);
			}
			var response = Gsr.Client.Rpc.call_value("Gsr-St-Viewport.create", null);
			this.rpc_lid = response.args.get(0).get_uint64();
			Gsr.Client.Rpc.register_handle(this);
			if (names.length > 0) {
				var hooks = Gsr.Client.Rpc.call_value(
					"Gsr-St-Viewport.add_hooks", this,
					OLLMrpc.args("Sv", names, vfunc_ids.end()));
				var ids = hooks.args.get(0).dup_variant();
				if (Gsr.Client.Rpc.handlers == null) {
					Gsr.Client.Rpc.handlers = new Gee.HashMap<int, Gsr.Client.Rpc.InvokeRow>();
				}
				var n = (int) ids.n_children();
				for (var i = 0; i < n; i++) {
					Gsr.Client.Rpc.handlers.set(
						(int) ids.get_child_value(i).get_uint64(),
						Gsr.Client.Rpc.hook_rows.get(i));
				}
			}
			Gsr.Client.Rpc.hook_rows = null;
			if (!batch || this.rpc_lid == 0) {
				return;
			}
			this.signal_overrides(this.get_type(), new Gee.ArrayList<string>());
			this.prop_batch_open = true;
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
