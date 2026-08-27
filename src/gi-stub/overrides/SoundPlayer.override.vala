		public void play_from_file(GLib.File file, string description, GLib.Cancellable? cancellable)
		{
			uint64 cancel_id = GnomeShellRpc.GiStub.CancellableBridge.register(cancellable);
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-SoundPlayer.play_from_file",
				this,
				OLLMrpc.args(
					"sst",
					file.get_uri(),
					description,
					cancel_id
				)
			);
		}

		public void play_from_theme(string name, string description, GLib.Cancellable? cancellable)
		{
			uint64 cancel_id = GnomeShellRpc.GiStub.CancellableBridge.register(cancellable);
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-SoundPlayer.play_from_theme",
				this,
				OLLMrpc.args("sst", name, description, cancel_id)
			);
		}
