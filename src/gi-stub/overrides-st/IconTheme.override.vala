		/**
		 * Stock {@code st_icon_theme_get_icon_sizes} — sizes on the wire as
		 * a raw int32 {@link GLib.Bytes} slab ({@code ay}).
		 */
		public int[] get_icon_sizes(string icon_name)
		{
			var response = GnomeShellRpc.call_value(
				"Helper-IconTheme.get_icon_sizes", this,
				OLLMrpc.args("s", icon_name));
			if (response.retval.type() != typeof(GLib.Bytes)) {
				return new int[0];
			}
			var blob = (GLib.Bytes) response.retval.get_boxed();
			if (blob == null || blob.get_size() == 0) {
				return new int[0];
			}
			var n = (int) (blob.get_size() / sizeof(int));
			var sizes = new int[n];
			GLib.Memory.copy(sizes, blob.get_data(), n * sizeof(int));
			return sizes;
		}
