		/**
		 * Stock {@code meta_selection_source_read_async}. Helper reads on the
		 * compositor; bytes come back on the reply buffer as a local
		 * {@link GLib.MemoryInputStream}.
		 */
		public async GLib.InputStream read_async(
			string mimetype,
			GLib.Cancellable? cancellable
		) throws GLib.Error {
			var cancel_id = GnomeShellRpc.GiStub.CancellableBridge.register(
				cancellable);
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-SelectionSource.read", this,
				OLLMrpc.args("st", mimetype, cancel_id));
			if (response.args.size < 1 || !response.args.get(0).get_boolean()
					|| response.buffer == null || response.buffer.fd < 0) {
				return new GLib.MemoryInputStream();
			}
			var nbytes = 0;
			if (response.args.size >= 2) {
				nbytes = (int) response.args.get(1).get_int64();
			}
			var data = new uint8[nbytes];
			if (nbytes > 0) {
				var fd = response.buffer.fd;
				Posix.lseek(fd, 0, Posix.SEEK_SET);
				var got = 0;
				while (got < nbytes) {
					var n = Posix.read(fd, (void*) &data[got], nbytes - got);
					if (n <= 0) {
						break;
					}
					got += (int) n;
				}
				if (got < nbytes) {
					throw new GLib.IOError.FAILED(
						"selection source read: short read from buffer");
				}
			}
			return new GLib.MemoryInputStream.from_data((owned) data, null);
		}
