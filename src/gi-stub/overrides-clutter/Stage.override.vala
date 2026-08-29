	/**
	 * Declared so {@code g_signal_connect (stage, "after-paint", …)} succeeds.
	 * Emission / Live.Subscribe forwarding is Phase 5 — connect must not CRITICAL.
	 */
	public signal void after_paint(StageView view, void* frame);
