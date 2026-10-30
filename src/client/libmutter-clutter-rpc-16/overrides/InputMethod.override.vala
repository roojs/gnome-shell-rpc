	/**
	 * Stock {@code clutter_input_method_notify_key_event}. The GJS
	 * InputMethod has no lease. When IBus did not filter the key, the
	 * compositor queues it with {@code CLUTTER_EVENT_FLAG_INPUT_METHOD}.
	 */
	public void notify_key_event(Event event, bool filtered)
	{
		if (filtered || event == null) {
			return;
		}
		Gsr.Client.Rpc.call_value("Gsr-Clutter.notify_key_event", null,
			OLLMrpc.args("iuuuu", (int) event.type(), event.get_time(),
				event.get_key_symbol(), (uint) event.get_state(), event.get_key_unicode()));
	}
