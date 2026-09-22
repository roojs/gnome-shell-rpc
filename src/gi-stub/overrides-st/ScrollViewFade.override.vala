		/**
		 * GIR property {@code fade-margins}. Generator emits only
		 * {@code get_fade_margins} / {@code set_fade_margins} (boxed
		 * {@code ay}); GJS reads {@code vfade.fade_margins.top}.
		 * Mutter has no {@code St-ScrollViewFade} handler — keep the
		 * struct on the client (same as ScrollView policies).
		 */
		private Clutter.Margin priv_fade_margins;

		public Clutter.Margin fade_margins {
			get {
				return this.priv_fade_margins;
			}
			set {
				this.priv_fade_margins = value;
			}
		}
