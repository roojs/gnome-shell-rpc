		/**
		 * Client-local — BarLevel / Slider need an {@link Atk.Object} for
		 * value signals; no server a11y peer on mock boot.
		 */
		public GenericAccessible.for_actor(Clutter.Actor actor)
		{
			Object();
		}

		/**
		 * Hand property — not missing from St GIR: {@code accessible-value}
		 * is declared on {@code Atk.Object} (deprecated), not on
		 * {@code St.GenericAccessible}. gi-stub-gen only walks the emit
		 * namespace (St) and does not re-emit foreign parent props; BarLevel
		 * calls {@code notify('accessible-value')} after value changes.
		 */
		public double accessible_value { get; set; default = 0; }
