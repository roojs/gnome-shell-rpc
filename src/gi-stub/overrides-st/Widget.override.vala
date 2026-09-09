		/**
		 * No lease construct here — {@code Actor.new} is denied and
		 * {@code Clutter.Actor}'s override parent-walks; {@code St-Widget}
		 * → {@code Helper-Actor.create}. {@code typeof(Widget)} would be
		 * the check if this class ever leased first.
		 */
