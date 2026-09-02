		[CCode (cname = "get_accessible_type")]
		private static extern GLib.Type dispatch_accessible_type(Actor actor);

		[CCode (cname = "clutter_actor_get_accessible")]
		public Atk.Object? get_accessible()
		{
			/* Local GJS/St actors: no server-side a11y object yet. */
			if (this.rpc_lid == 0) {
				return null;
			}
			/* StWidget is C layout (no rpc_lid); only Vala/Gjs actors use the lease field. */
			if (!this.get_type().name().has_prefix("St")) {
				var response = GnomeShellRpc.GiStub.Runtime.call_values(
					"Clutter-Actor.get_accessible", this);
				return (Atk.Object) response.retval.get_object();
			}
			var type = Actor.dispatch_accessible_type(this);
			if (type == GLib.Type.INVALID) {
				return null;
			}
			return (Atk.Object) GLib.Object.new(type);
		}

		[CCode (cname = "clutter_actor_destroy")]
		public void destroy_rpc()
		{
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.destroy", this);
		}

		[CCode (cname = "clutter_actor_add_child")]
		public void add_child(Actor child)
		{
			/* GJS/St actors are local-only until leased; skip RPC with lid 0. */
			if (this.rpc_lid == 0 || child.rpc_lid == 0) {
				return;
			}
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.add_child", this,
				OLLMrpc.args("o", child));
		}

		[CCode (cname = "clutter_actor_remove_child")]
		public void remove_child(Actor child)
		{
			if (this.rpc_lid == 0 || child.rpc_lid == 0) {
				return;
			}
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.remove_child", this,
				OLLMrpc.args("o", child));
		}

		[CCode (cname = "clutter_actor_add_constraint")]
		public void add_constraint(Constraint constraint)
		{
			if (this.rpc_lid == 0 || constraint.rpc_lid == 0) {
				return;
			}
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.add_constraint", this,
				OLLMrpc.args("o", constraint));
		}
