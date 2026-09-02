		/**
		 * Lease a server StWidget for {@code new St.Widget()} and GJS
		 * subclasses ({@code Gjs_*}) — not for stock St types that extend
		 * Widget and run their own {@code St-* .new} in {@code construct}.
		 */
		construct {
			var t = this.get_type();
			if (!t.is_a(typeof(Widget))) {
				return;
			}
			if (t != typeof(Widget) && !t.name().has_prefix("Gjs_")) {
				return;
			}
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"St-Widget.new", null);
			var _stub = response.retval.get_object() as OLLMrpc.Live.Handle;
			this.rpc_lid = _stub.rpc_lid;
		}
