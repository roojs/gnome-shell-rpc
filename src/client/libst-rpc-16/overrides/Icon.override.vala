		/**
		 * {@link GLib.Icon} is not on the object wire — serialize with
		 * {@code to_string()} / {@code new_for_string()} via Gsr-St-Icon.
		 */
		public GLib.Icon gicon {
			owned get {
				var response = Gsr.Client.Rpc.call_value(
					"Gsr-St-Icon.get_gicon", this);
				unowned string? s = response.retval.get_string();
				if (s == null || s.length == 0) {
					return null;
				}
				try {
					return GLib.Icon.new_for_string(s);
				} catch (GLib.Error e) {
					return null;
				}
			}
			set {
				string s = "";
				if (value != null) {
					string? wire = value.to_string();
					s = wire != null ? wire : "";
				}
				Gsr.Client.Rpc.call_value(
					"Gsr-St-Icon.set_gicon", this, OLLMrpc.args("s", s));
			}
		}

		public GLib.Icon fallback_gicon {
			owned get {
				var response = Gsr.Client.Rpc.call_value(
					"Gsr-St-Icon.get_fallback_gicon", this);
				unowned string? s = response.retval.get_string();
				if (s == null || s.length == 0) {
					return null;
				}
				try {
					return GLib.Icon.new_for_string(s);
				} catch (GLib.Error e) {
					return null;
				}
			}
			set {
				string s = "";
				if (value != null) {
					string? wire = value.to_string();
					s = wire != null ? wire : "";
				}
				Gsr.Client.Rpc.call_value(
					"Gsr-St-Icon.set_fallback_gicon", this,
					OLLMrpc.args("s", s));
			}
		}
