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
			/*
			 * @layout.<name> is the client layout manager's property.
			 * GJS installs it (LabelExpanderLayout.expansion). The server
			 * stand-in from create_server_manager() does not have it, so
			 * this lookup cannot be an RPC.
			 */
			if (property_name.has_prefix("@layout.")) {
				var layout = this.layout_manager;
				if (layout == null) {
					return null;
				}
				var name = property_name.substring("@layout.".length);
				if (name.index_of(".") >= 0) {
					return null;
				}
				return ((GLib.Object) layout).get_class().find_property(name);
			}
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
