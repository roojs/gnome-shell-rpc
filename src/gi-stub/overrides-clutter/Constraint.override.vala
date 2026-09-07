		/**
		 * ActorMeta props — parent is a size-locked C GType (no Vala props).
		 * GJS: {@code new AlignConstraint({ name: 'align', … })}.
		 */
		private string priv_name;
		private bool priv_enabled = true;

		public string name {
			get {
				return this.priv_name;
			}
			set construct {
				this.priv_name = value;
			}
		}

		public bool enabled {
			get {
				return this.priv_enabled;
			}
			set construct {
				this.priv_enabled = value;
			}
		}

		private void sync_actor_meta_name()
		{
			if (this.rpc_lid == 0
					|| this.priv_name == null
					|| this.priv_name.length == 0) {
				return;
			}
			GnomeShellRpc.call_value("Clutter-ActorMeta.set_name", this,
				OLLMrpc.args("s", this.priv_name));
		}

		private void sync_actor_meta_enabled()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			GnomeShellRpc.call_value("Clutter-ActorMeta.set_enabled", this,
				OLLMrpc.args("b", this.priv_enabled));
		}

		/**
		 * Stock Align/Bind/Snap and JS subclasses lease via
		 * {@code Helper-Constraint.create} → server {@link ConstraintRelay}
		 * (or Align/Bind/Snap subclass). Leaf {@code Clutter-*.new} is not
		 * Ffi-owned (GObject {@code *_new} clash); Helper matches other overrides.
		 *
		 * name/enabled setters only store; sync after lease. Syncing from
		 * setters nested-RPCs during wire decode of {@code get_constraint}
		 * replies (logged: construct with rpc_lid set must not call out).
		 */
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var self = this;
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				var actor = (Actor) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				var box = ActorBox();
				box.x1 = (float) call.args.get(1).get_double();
				box.y1 = (float) call.args.get(2).get_double();
				box.x2 = (float) call.args.get(3).get_double();
				box.y2 = (float) call.args.get(4).get_double();
				self.update_allocation(actor, box);
				return OLLMrpc.args("dddd",
					(double) box.x1, (double) box.y1,
					(double) box.x2, (double) box.y2);
			});
			var response = GnomeShellRpc.call_value(
				"Helper-Constraint.create",
				null,
				OLLMrpc.args("t", callback_id));
			this.rpc_lid = response.args.get(0).get_uint64();
			this.sync_actor_meta_name();
			this.sync_actor_meta_enabled();
		}
