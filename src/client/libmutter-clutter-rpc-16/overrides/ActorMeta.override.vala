		/**
		 * GIR accessors, not Vala properties. A property setter runs while
		 * GJS constructs {@code new FadeEffect({ name, enabled })}, before
		 * the subclass has a lease. Subclasses keep their own properties
		 * and call these after {@code rpc_lid} is set. {@code actor} is read-only.
		 */
		public Actor get_actor()
		{
			var response = Gsr.call_value("Clutter-ActorMeta.get_actor", this);
			return (Actor) response.retval.get_object();
		}

		public bool get_enabled()
		{
			var response = Gsr.call_value("Clutter-ActorMeta.get_enabled", this);
			return response.retval.get_boolean();
		}

		public void set_enabled(bool is_enabled)
		{
			Gsr.call_value("Clutter-ActorMeta.set_enabled", this, OLLMrpc.args("b", is_enabled));
		}

		public owned string get_name()
		{
			var response = Gsr.call_value("Clutter-ActorMeta.get_name", this);
			if (response.retval.type() == typeof(int) && response.retval.get_int() == 0) {
				return "";
			}
			unowned string? name = response.retval.get_string();
			return name != null ? name.dup() : "";
		}

		public void set_name(string name)
		{
			Gsr.call_value("Clutter-ActorMeta.set_name", this, OLLMrpc.args("s", name));
		}
