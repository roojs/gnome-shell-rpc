		/**
		 * ActorMeta props — parent is a size-locked C GType (no Vala props).
		 * GJS: {@code new AlignConstraint({ name: 'align', … })}.
		 * {@code enabled} must GParamSpec-default true (stock ActorMeta);
		 * construct FALSE was syncing set_enabled(false) and skipping
		 * update_allocation — see bugs/done/2026-09-15-chrome-placement.md.
		 */
		public string name { get; set construct; }
		public bool enabled { get; set construct; default = true; }

		private void sync_actor_meta_name()
		{
			if (this.rpc_lid == 0
					|| this.name == null
					|| this.name.length == 0) {
				return;
			}
			GnomeShellRpc.call_value("Clutter-ActorMeta.set_name", this,
				OLLMrpc.args("s", this.name));
		}

		private void sync_actor_meta_enabled()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			GnomeShellRpc.call_value("Clutter-ActorMeta.set_enabled", this,
				OLLMrpc.args("b", this.enabled));
		}

		/**
		 * Class slot takes {@code ClutterActorBox*} (GIR). Vala
		 * {@code update_allocation(..., ActorBox)} is by-value — a local
		 * copy is mutated and the reply would keep the pre-call box.
		 * Call the public invoker with {@code ref} so GJS {@code init_rect}
		 * sticks in the wire reply.
		 */
		[CCode (cname = "clutter_constraint_update_allocation")]
		private static extern void invoke_update_allocation(
			Constraint self,
			Actor actor,
			ref ActorBox allocation
		);

		/**
		 * Mint the compositor peer. Base = {@code Helper-Constraint.create}
		 * (JS subclasses). Align/Bind/Snap override to their leaf {@code .new}.
		 */
		protected virtual void mint_server_lease()
		{
			var self = this;
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				var actor = (Actor) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				var box = ActorBox();
				box.x1 = (float) call.args.get(1).get_double();
				box.y1 = (float) call.args.get(2).get_double();
				box.x2 = (float) call.args.get(3).get_double();
				box.y2 = (float) call.args.get(4).get_double();
				invoke_update_allocation(self, actor, ref box);
				return OLLMrpc.args("dddd",
					(double) box.x1, (double) box.y1,
					(double) box.x2, (double) box.y2);
			});
			var response = GnomeShellRpc.call_value(
				"Helper-Constraint.create",
				null,
				OLLMrpc.args("t", callback_id));
			this.rpc_lid = response.args.get(0).get_uint64();
		}

		/**
		 * name/enabled setters only store; sync after lease (no nested RPC
		 * during wire decode of {@code get_constraint} replies).
		 */
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			this.mint_server_lease();
			this.sync_actor_meta_name();
			this.sync_actor_meta_enabled();
		}
