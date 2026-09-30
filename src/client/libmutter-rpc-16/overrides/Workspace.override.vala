		GLib.Variant? last_struts;
		Display? cached_display;
		Gee.HashMap<int, GLib.Bytes>? work_area_bytes;

		public Display? get_display()
		{
			if (this.cached_display != null) {
				return this.cached_display;
			}
			var response = GnomeShellRpc.call_value(
				"Meta-Workspace.get_display", this);
			if (response.retval.type() == GLib.Type.INVALID) {
				return null;
			}
			this.cached_display = (Display) response.retval.get_object();
			return this.cached_display;
		}

		public void get_work_area_for_monitor(
			int32 which_monitor,
			out Mtk.Rectangle area
		) {
			if (this.work_area_bytes != null
					&& this.work_area_bytes.has_key((int) which_monitor)) {
				var blob = this.work_area_bytes.get((int) which_monitor);
				area = *((Mtk.Rectangle*) blob.get_data());
				return;
			}
			var response = GnomeShellRpc.call_value(
				"Meta-Workspace.get_work_area_for_monitor", this,
				OLLMrpc.args("i", (int) which_monitor));
			var blob0 = (GLib.Bytes) response.args.get(0).get_boxed();
			area = *((Mtk.Rectangle*) blob0.get_data());
			if (this.work_area_bytes == null) {
				this.work_area_bytes = new Gee.HashMap<int, GLib.Bytes>();
			}
			this.work_area_bytes.set((int) which_monitor, blob0);
		}

		public void set_builtin_struts(GLib.SList<Strut?> struts)
		{
			var struts_aay_builder = new GLib.VariantBuilder(
				new GLib.VariantType("aay"));
			for (unowned GLib.SList<Strut?>? _struts_node = struts;
					_struts_node != null;
					_struts_node = _struts_node.next) {
				uint8[] _struts_data = new uint8[sizeof(Strut)];
				*((Strut*) _struts_data) = _struts_node.data;
				struts_aay_builder.add_value(new GLib.Variant.from_bytes(
					new GLib.VariantType("ay"),
					new GLib.Bytes(_struts_data), true));
			}
			var struts_aay = struts_aay_builder.end();
			/* layout.js _updateRegions every BEFORE_REDRAW. Stock mutter
			 * only emits workareas-changed when struts change. Emitting
			 * every call → MonitorConstraint queue_relayout →
			 * notify::allocation → _queueUpdateRegions again. */
			if (this.last_struts != null && this.last_struts.equal(struts_aay)) {
				return;
			}
			this.last_struts = struts_aay;
			this.work_area_bytes = null;
			GnomeShellRpc.call_value(
				"Meta-Workspace.set_builtin_struts", this,
				OLLMrpc.args("v", struts_aay));
			/* OPC subscribe did not deliver Display::workareas-changed. */
			var display = this.get_display();
			if (display != null) {
				GLib.Signal.emit_by_name(display, "workareas-changed");
			}
		}
