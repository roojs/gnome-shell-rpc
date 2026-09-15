		/**
		 * Animatable is an iface — generator leaves set/get_animatable
		 * not_wired. Adjustment.ease needs the helper Transition bound
		 * before {@code start}.
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

		/**
		 * GIR {@code set_to} is shadowed by {@code set_to_value}; GJS
		 * {@code transition.set_to(x)} looks up the C symbol
		 * {@code clutter_transition_set_to_value}.
		 *
		 * Generator emits {@code set_to} as a memcpy {@code ay} blob of
		 * {@link GLib.Value} — that is not a wire encoding. Pass the
		 * Value as a normal call arg; OPC {@code StreamValue} + Gi
		 * {@code value_keep} already handle {@code GValue*} IN.
		 */
		[CCode (cname = "clutter_transition_set_to_value")]
		public void set_to_value(GLib.Value value)
		{
			var args = new Gee.ArrayList<GLib.Value?>();
			args.add(value);
			GnomeShellRpc.call_value(
				"Clutter-Transition.set_to_value", this, args);
		}

		[CCode (cname = "clutter_transition_set_from_value")]
		public void set_from_value(GLib.Value value)
		{
			var args = new Gee.ArrayList<GLib.Value?>();
			args.add(value);
			GnomeShellRpc.call_value(
				"Clutter-Transition.set_from_value", this, args);
		}
