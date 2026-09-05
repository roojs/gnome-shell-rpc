		/**
		 * Client-owned for {@code layout.js} JSObject
		 * {@code new Clutter.BindConstraint({ source, coordinate })}.
		 * Lease: generated {@code construct} on {@code Clutter-BindConstraint.new}.
		 */
		public Actor? source { get; set construct; }
		public BindCoordinate coordinate { get; set construct; default = BindCoordinate.all;}
		public float offset { get; set construct; default = 0; }
