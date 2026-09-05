		/**
		 * Fallback lease when no more-derived {@code St.*} construct ran first.
		 *
		 * Vala {@code construct} runs derived → base. Types with a wired
		 * {@code St-* .new} (generator {@code emit_lease_construct}) lease there
		 * for every {@code is_a} match — stock {@code new St.BoxLayout()} and
		 * {@code Gjs_*} subclasses alike. This block runs only if {@code rpc_lid}
		 * is still zero (direct {@code St.Widget} / {@code Gjs_* extends Widget}).
		 */
		construct {
			if (this.rpc_lid != 0) {
				return;
			}
			if (!this.get_type().is_a(typeof(Widget))) {
				return;
			}
			var response = GnomeShellRpc.call_value(
				"St-Widget.new", null);
			var _stub = response.retval.get_object() as OLLMrpc.Live.Handle;
			this.rpc_lid = _stub.rpc_lid;
		}
