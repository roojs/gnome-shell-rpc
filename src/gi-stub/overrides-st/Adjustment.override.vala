		/**
		 * Client-owned transitions for workspaces adjustment. Scalar props
		 * RPC via generated get/set; lease minted here ({@code Adjustment.new}
		 * denied — GIR ctor needs actor + six doubles, lease construct would
		 * call {@code .new} with no args).
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

		public void add_transition(string name, Clutter.Transition transition)
		{
			this.transitions.set(name, transition);
		}

		[CCode (cname = "st_adjustment_get_transition")]
		public Clutter.Transition? get_transition(string name)
		{
			return this.transitions.get(name);
		}

		public void remove_transition(string name)
		{
			this.transitions.unset(name);
		}
