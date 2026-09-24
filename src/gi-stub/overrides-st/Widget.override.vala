		construct {
			this.signal_style_changed.connect(() => {
				this.style_changed_vfunc();
			});
		}

		void emit_style_changed_after_rpc()
		{
			this.signal_style_changed();
		}

		public GLib.ParamSpec? find_property(string property_name)
		{
			return ((GLib.Object) this).get_class().find_property(property_name);
		}

		public void get_initial_state(string property_name, GLib.Value value)
		{
			GLib.Value tmp = value;
			this.get_property(property_name, ref tmp);
			value = tmp;
		}

		public void set_final_state(string property_name, GLib.Value value)
		{
			this.set_property(property_name, value);
		}

		public bool interpolate_value(
			string property_name,
			Clutter.Interval interval,
			double progress,
			out GLib.Value value
		) {
			return interval.compute_value(progress, out value);
		}

		public Clutter.Actor? get_actor()
		{
			return this;
		}
