		/**
		 * Animatable is an iface — generator leaves set/get_animatable
		 * not_wired. Adjustment.ease needs the helper Transition bound
		 * before {@code start}.
		 *
		 * set_to_value / set_from_value: capital-V over stock Gi
		 * (OLLMchat docs/bugs/2026-09-16-bin-capital-v-value.md).
		 */
		public void set_animatable(Animatable? animatable)
		{
			GnomeShellRpc.call_value("Clutter-Transition.set_animatable", this,
				OLLMrpc.args("o", animatable));
		}

		public Animatable get_animatable()
		{
			var response = GnomeShellRpc.call_value(
				"Clutter-Transition.get_animatable", this);
			return (Animatable) response.retval.get_object();
		}

		public void set_to_value(GLib.Value value)
		{
			GnomeShellRpc.call_value("Clutter-Transition.set_to_value", this,
				OLLMrpc.args("V", value));
		}

		public void set_from_value(GLib.Value value)
		{
			GnomeShellRpc.call_value("Clutter-Transition.set_from_value", this,
				OLLMrpc.args("V", value));
		}
