		/**
		 * Animatable is an iface — generator leaves set/get_animatable
		 * not_wired. Adjustment.ease needs the helper Transition bound
		 * before {@code start}.
		 *
		 * Client Vala is set_*_value (GJS); Gi typelib name is set_to /
		 * set_from (GIR shadows). Wire that name + capital-V.
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
			GnomeShellRpc.call_value("Clutter-Transition.set_to", this,
				OLLMrpc.args("V", value));
		}

		public void set_from_value(GLib.Value value)
		{
			GnomeShellRpc.call_value("Clutter-Transition.set_from", this,
				OLLMrpc.args("V", value));
		}
