		/**
		 * Client-owned transitions for workspaces adjustment. Scalar props
		 * RPC via generated get/set; lease minted here ({@code Adjustment.new}
		 * denied — GIR ctor needs actor + six doubles, lease construct would
		 * call {@code .new} with no args).
		 *
		 * Stock implements {@link Clutter.Animatable} (typelib from distro
		 * GIR); generator emits it via {@code Adjustment.implements=…}.
		 * Animatable defaults match clutter’s GObject property path; only
		 * {@code get_actor} is St-specific. {@code add_transition} must
		 * {@code animatable} + {@code start} like
		 * {@code st_adjustment_add_transition}.
		 */
		private Gee.HashMap<string, Clutter.Transition> transitions {
			get; default = new Gee.HashMap<string, Clutter.Transition>();
		}

		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			var response = GnomeShellRpc.call_value(
				"St-Adjustment.new",
				null,
				OLLMrpc.args("odddddd",
					null, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0));
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Handle).rpc_lid;
		}

		public Adjustment()
		{
			Object();
		}

		public GLib.ParamSpec? find_property(string property_name)
		{
			return ((GLib.Object) this).get_class().find_property(property_name);
		}

		public void get_initial_state(string property_name, GLib.Value value)
		{
			GLib.Value tmp = value;
			this.get_property(property_name, ref tmp);
			value = tmp;
		}

		public void set_final_state(string property_name, GLib.Value value)
		{
			this.set_property(property_name, value);
		}

		public bool interpolate_value(
			string property_name,
			Clutter.Interval interval,
			double progress,
			out GLib.Value value
		) {
			return interval.compute_value(progress, out value);
		}

		public Clutter.Actor? get_actor()
		{
			return this.actor;
		}

		public void add_transition(string name, Clutter.Transition transition)
		{
			if (this.transitions.has_key(name)) {
				GLib.warning(
					"A transition with name '%s' already exists for adjustment",
					name);
				return;
			}
			/* Same arm as Actor.get_transition — ease onComplete needs stopped. */
			GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(
				transition, "stopped");
			transition.animatable = this;
			this.transitions.set(name, transition);
			ulong stopped_id = 0;
			stopped_id = transition.stopped.connect((t, finished) => {
				if (transition.remove_on_complete) {
					this.transitions.unset(name);
				}
				if (stopped_id != 0) {
					transition.disconnect(stopped_id);
					stopped_id = 0;
				}
			});
			transition.start();
		}

		[CCode (cname = "st_adjustment_get_transition")]
		public Clutter.Transition? get_transition(string name)
		{
			return this.transitions.get(name);
		}

		public void remove_transition(string name)
		{
			Clutter.Transition? t = this.transitions.get(name);
			if (t != null) {
				t.stop();
			}
			this.transitions.unset(name);
		}
