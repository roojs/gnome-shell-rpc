	/**
	 * GIR also has a method {@code event}; denied so this signal can use the
	 * stock name. {@code st_focus_manager_get_for_stage} connects it.
	 */
	public signal bool event(Event event);

	/**
	 * GIR method {@code destroy} denied — name clashes with this signal.
	 * Stock {@code clutter_actor_destroy} is {@link destroy_rpc}.
	 */
	public signal void destroy();

	/**
	 * Stock {@code clutter_actor_destroy} C ABI (method body was denied above).
	 */
	[CCode (cname = "clutter_actor_destroy")]
	public void destroy_rpc()
	{
		GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-Actor.destroy", this);
	}

	/**
	 * Lease handle in {@code args[0]} — Helper packs uint64, not {@code result}.
	 */
	public Context get_context()
	{
		var response = GnomeShellRpc.GiStub.Runtime.call_values(
			"Clutter-Actor.get_context", this);
		var ctx = new Context();
		if (response.args.size > 0) {
			ctx.set_data_full(
				"gsr-lease-id",
				(void*) response.args.get(0).get_uint64(),
				null
			);
		}
		return ctx;
	}
