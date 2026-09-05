		/**
		 * Client-local — {@code enabled} is an {@link ActorMeta} property, but
		 * ActorMeta is a size-locked C GType (no Vala props). GJS constructs
		 * {@code new ClickAction({ enabled })} and connects {@code notify::pressed}.
		 */
		public bool enabled { get; set construct; default = true; }
		public bool pressed { get; private set; default = false; }
