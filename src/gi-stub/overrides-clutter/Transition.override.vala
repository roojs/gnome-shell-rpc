		/**
		 * Animatable is an iface — generator leaves set/get_animatable
		 * not_wired. Adjustment.ease needs the helper Transition bound
		 * before {@code start}.
		 *
		 * set_to / set_from: TEMPORARY deny (no body here) until GValue IN
		 * is fixed in the generator — see bug §2 / Clutter.deny TEMPORARY.
		 */
		public void set_animatable(Animatable? animatable)
		{
			GnomeShellRpc.call_value(
				"Clutter-Transition.set_animatable",
				this,
				OLLMrpc.args("o", animatable));
		}

		public Animatable get_animatable()
		{
			var response = GnomeShellRpc.call_value(
				"Clutter-Transition.get_animatable", this);
			return (Animatable) response.retval.get_object();
		}
