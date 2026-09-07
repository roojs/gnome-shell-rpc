		/**
		 * Client-owned transitions for workspaces adjustment; props come from
		 * generator ({@code Adjustment props=local} in St.overrides).
		 */
		private Gee.HashMap<string, Clutter.Transition> transitions {
			get; default = new Gee.HashMap<string, Clutter.Transition>();
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
