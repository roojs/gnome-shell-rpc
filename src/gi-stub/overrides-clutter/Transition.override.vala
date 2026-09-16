		/**
		 * Animatable is an iface — generator leaves set/get_animatable
		 * not_wired. Adjustment.ease needs the helper Transition bound
		 * before {@code start}.
		 *
		 * set_to_value / set_from_value: typed Helper-Transition.set_relay_value
		 * (bsid) — see docs/bugs/2026-09-16-transition-interval-gvalue-wire.md.
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
			this.relay_value(true, value);
		}

		public void set_from_value(GLib.Value value)
		{
			this.relay_value(false, value);
		}

		void relay_value(bool is_to, GLib.Value value)
		{
			string kind = "";
			int i = 0;
			double d = 0.0;
			var t = value.type();
			switch (t) {
				case GLib.Type.INT:
					kind = "i";
					i = value.get_int();
					break;
				case GLib.Type.UINT:
					kind = "u";
					i = (int) value.get_uint();
					break;
				case GLib.Type.BOOLEAN:
					kind = "b";
					i = value.get_boolean() ? 1 : 0;
					break;
				case GLib.Type.CHAR:
					kind = "c";
					i = value.get_schar();
					break;
				case GLib.Type.UCHAR:
					kind = "y";
					i = value.get_uchar();
					break;
				case GLib.Type.FLOAT:
					kind = "f";
					d = value.get_float();
					break;
				case GLib.Type.DOUBLE:
					kind = "d";
					d = value.get_double();
					break;
				default:
					GLib.warning("Transition.relay_value: unsupported %s", t.name());
					return;
			}
			GnomeShellRpc.call_value("Helper-Transition.set_relay_value", this,
				OLLMrpc.args("bsid", is_to, kind, i, d));
		}
