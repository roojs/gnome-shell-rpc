	/**
	 * Shell {@code InputMethod} is a client GJS subclass — no {@code rpc_lid}.
	 * Stock is in-process; generated RPC stubs abort on the pointer. Keep local.
	 */
	public InputMethod? input_method { get; set; }

	/**
	 * Stock {@code clutter_backend_get_sprite}. The compositor matches
	 * this event to the current event and returns that sprite lease.
	 *
	 * @param stage the stage the sprite is on
	 * @param event the event shell is handling
	 * @return the sprite, or null when the compositor has none
	 */
	[CCode (cname = "clutter_backend_get_sprite")]
	public Sprite? get_sprite(Stage stage, Event event)
	{
		var response = Gsr.Client.Rpc.call_value(
			"Clutter-Backend.get_sprite", this,
			OLLMrpc.args("tuu", stage.rpc_lid, (uint) event.type(),
				event.get_time()));
		if (response.args.size < 1) {
			return null;
		}
		var handle = response.args.get(0).get_uint64();
		if (handle == 0) {
			return null;
		}
		if (Gsr.Client.Rpc.client.proxies.has_key((int) handle)) {
			var existing = Gsr.Client.Rpc.client.proxies.get((int) handle) as Sprite;
			if (existing != null) {
				return existing;
			}
		}
		var sprite = new Sprite() {
			rpc_lid = handle,
		};
		Gsr.Client.Rpc.register_handle(sprite);
		return sprite;
	}

	/**
	 * Stock {@code clutter_backend_get_pointer_sprite}.
	 *
	 * @param stage the stage the pointer sprite is on
	 * @return the pointer sprite, or null
	 */
	[CCode (cname = "clutter_backend_get_pointer_sprite")]
	public Sprite? get_pointer_sprite(Stage stage)
	{
		var response = Gsr.Client.Rpc.call_value(
			"Clutter-Backend.get_pointer_sprite", this,
			OLLMrpc.args("t", stage.rpc_lid));
		if (response.args.size < 1) {
			return null;
		}
		var handle = response.args.get(0).get_uint64();
		if (handle == 0) {
			return null;
		}
		if (Gsr.Client.Rpc.client.proxies.has_key((int) handle)) {
			var existing = Gsr.Client.Rpc.client.proxies.get((int) handle) as Sprite;
			if (existing != null) {
				return existing;
			}
		}
		var sprite = new Sprite() {
			rpc_lid = handle,
		};
		Gsr.Client.Rpc.register_handle(sprite);
		return sprite;
	}
