		public void set_builtin_struts(GLib.SList<Strut?> struts)
		{
			var struts_aay_builder = new GLib.VariantBuilder(new GLib.VariantType("aay"));
			for (unowned GLib.SList<Strut?>? _struts_node = struts; _struts_node != null; _struts_node = _struts_node.next) {
				uint8[] _struts_data = new uint8[sizeof(Strut)];
				*((Strut*) _struts_data) = _struts_node.data;
				struts_aay_builder.add_value(new GLib.Variant.from_bytes(new GLib.VariantType("ay"), new GLib.Bytes(_struts_data), true));
			}
			var struts_aay = struts_aay_builder.end();
			GnomeShellRpc.call_value("Meta-Workspace.set_builtin_struts", this, OLLMrpc.args("v", struts_aay));
			/* Stock mutter emits Display::workareas-changed after struts.
			 * OPC subscribe did not deliver a Notification (smoke C). */
			var display = this.get_display();
			if (display != null) {
				GLib.Signal.emit_by_name(display, "workareas-changed");
			}
		}
