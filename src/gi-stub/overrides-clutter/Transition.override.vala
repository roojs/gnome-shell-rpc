		/**
		 * Client Vala is set_*_value (GJS); Gi typelib name is set_to /
		 * set_from (GIR shadows). Wire that name + capital-V.
		 * {@code animatable} is a generated GIR property (object getter).
		 */

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
