	/**
	 * Lease handle in {@code args[0]} — Helper packs uint64, not {@code retval}.
	 */
	public Backend get_backend()
	{
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-Context.get_backend", this);
		var backend = new Backend();
		if (response.args.size > 0) {
			backend.set_data_full(
				"gsr-lease-id",
				(void*) response.args.get(0).get_uint64(),
				null
			);
		}
		return backend;
	}
