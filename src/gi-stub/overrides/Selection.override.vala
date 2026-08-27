		/**
		 * Stock {@code meta_selection_transfer_async}. Helper fills a memory
		 * stream on the compositor; bytes come back on the reply buffer and
		 * are written into {@code output} here.
		 */
		public async bool transfer_async(
			SelectionType selection_type,
			string mimetype,
			ssize_t size,
			GLib.OutputStream output,
			GLib.Cancellable? cancellable
		) throws GLib.Error {
			var cancel_id = GnomeShellRpc.GiStub.CancellableBridge.register(
				cancellable);
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Selection.transfer", this,
				OLLMrpc.args("isxt", (int) selection_type, mimetype,
					(int64) size, cancel_id));
			if (response.args.size < 1 || !response.args.get(0).get_boolean()) {
				return false;
			}
			var nbytes = 0;
			if (response.args.size >= 2) {
				nbytes = (int) response.args.get(1).get_int64();
			}
			if (response.buffer == null || response.buffer.fd < 0
					|| nbytes <= 0) {
				return true;
			}
			var data = new uint8[nbytes];
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
					"selection transfer: short read from buffer");
			}
			size_t written;
			output.write_all(data, out written, cancellable);
			return true;
		}
