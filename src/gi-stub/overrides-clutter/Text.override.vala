		/**
		 * Stock {@code clutter_text_get_layout}. Helper-Text returns the
		 * fields; this builds a client {@link Pango.Layout}. Writes here
		 * do not go back to the server layout.
		 */
		public Pango.Layout? get_layout()
		{
			var response = GnomeShellRpc.call_value("Helper-Text.get_layout", this);
			if (response.args.size < 10) {
				return null;
			}
			var layout = new Pango.Layout(Pango.CairoFontMap.get_default().create_context());
			string text = response.args.get(0).get_string();
			string font = response.args.get(1).get_string();
			string attrs = response.args.get(9).get_string();
			layout.set_text(text, -1);
			if (font.length > 0) {
				layout.set_font_description(Pango.FontDescription.from_string(font));
			}
			layout.set_width((int) response.args.get(2).get_int());
			layout.set_height((int) response.args.get(3).get_int());
			layout.set_wrap((Pango.WrapMode) response.args.get(4).get_int());
			layout.set_ellipsize((Pango.EllipsizeMode) response.args.get(5).get_int());
			layout.set_alignment((Pango.Alignment) response.args.get(6).get_int());
			layout.set_indent((int) response.args.get(7).get_int());
			layout.set_spacing((int) response.args.get(8).get_int());
			if (attrs.length > 0) {
				var list = Pango.AttrList.from_string(attrs);
				if (list != null) {
					layout.set_attributes(list);
				}
			}
			return layout;
		}
