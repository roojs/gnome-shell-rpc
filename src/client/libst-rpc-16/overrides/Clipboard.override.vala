	[CCode (cname = "memfd_create", cheader_filename = "sys/mman.h")]
	private static extern int memfd_create(string name, uint flags);

	[CCode (has_target = false)]
	public delegate void ClipboardGetTextFunc(
		Clipboard clipboard,
		string? text,
		void* user_data
	);

	/**
	 * Stock {@code st_clipboard_get_text}. The callback is async on the
	 * compositor; shellEntry paste reads the text from it.
	 */
	public void get_text(
		ClipboardType type,
		ClipboardGetTextFunc callback,
		void* user_data
	) {
		uint64 callback_id = 0;
		callback_id = Gsr.Client.Rpc.callback_bind((call) => {
			string? text = null;
			if (call.args.size > 1 && call.args.get(0).get_boolean()) {
				text = call.args.get(1).get_string();
			}
			callback(this, text, user_data);
			Gsr.Client.Rpc.callback_unbind(callback_id);
			return null;
		});
		Gsr.Client.Rpc.call_value(
			"Gsr-St-Clipboard.get_text", this,
			OLLMrpc.args("it", (int) type, callback_id));
	}

	/**
	 * Stock {@code st_clipboard_set_content}. Bytes go on the request
	 * memfd, same as {@link ImageContent.set_data}.
	 */
	public void set_content(
		ClipboardType type,
		string mimetype,
		GLib.Bytes bytes
	) {
		if (bytes == null || mimetype == null) {
			return;
		}
		unowned uint8[] data = bytes.get_data();
		var nbytes = data.length;
		var fd = memfd_create("gsr-clip", 1);
		if (fd < 0 || Posix.write(fd, data, nbytes) != nbytes) {
			if (fd >= 0) {
				Posix.close(fd);
			}
			GLib.warning("Clipboard.set_content memfd");
			return;
		}
		Posix.lseek(fd, 0, Posix.SEEK_SET);
		Gsr.Client.Rpc.call_value(
			"Gsr-St-Clipboard.set_content", this,
			OLLMrpc.args("isx", (int) type, mimetype, (int64) nbytes),
			new OLLMrpc.Live.Buffer(fd));
	}
