		/**
		 * Client-local — {@code enabled} is an {@link ActorMeta} method, not
		 * a property. GJS constructs {@code new ClickGesture({ enabled })}.
		 * {@code pressed} is already on {@link PressGesture}.
		 */
		public bool enabled { get; set construct; default = true; }
