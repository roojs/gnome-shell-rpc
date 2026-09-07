		/**
		 * GIR {@code child} — generator left get/set as unwired errors
		 * (Scrollable iface). Non-construct so lease exists first; GJS
		 * {@code new St.ScrollView({ child: view })}.
		 */
		public Scrollable? child {
			get {
				var response = GnomeShellRpc.call_value(
					"St-ScrollView.get_child", this);
				return response.retval.get_object() as Scrollable;
			}
			set {
				GnomeShellRpc.call_value(
					"St-ScrollView.set_child", this,
					OLLMrpc.args("o", value));
			}
		}

		/**
		 * GIR writable props without getters (only {@code set_policy}) —
		 * generator skips them. Defaults match St-16.gir.
		 * Not {@code construct}: GObject would apply defaults during
		 * {@code Object.new(..., "rpc-lid", …)} decode and nest
		 * {@code set_policy} inside the reply parse → connection deadlock.
		 * GJS sets these after construct when the lease already exists.
		 */
		private PolicyType priv_hscrollbar_policy = PolicyType.never;
		private PolicyType priv_vscrollbar_policy = PolicyType.automatic;

		public PolicyType hscrollbar_policy {
			get {
				return this.priv_hscrollbar_policy;
			}
			set {
				this.priv_hscrollbar_policy = value;
				this.sync_scrollbar_policy();
			}
		}

		public PolicyType vscrollbar_policy {
			get {
				return this.priv_vscrollbar_policy;
			}
			set {
				this.priv_vscrollbar_policy = value;
				this.sync_scrollbar_policy();
			}
		}

		private void sync_scrollbar_policy()
		{
			if (this.rpc_lid == 0) {
				return;
			}
			this.set_policy(
				this.priv_hscrollbar_policy,
				this.priv_vscrollbar_policy);
		}
