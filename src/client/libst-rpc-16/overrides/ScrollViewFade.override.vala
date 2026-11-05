		/*
		 * Stock returns a borrowed pointer. A Vala struct auto-property emits
		 * void (self, out result), which is not ABI-compatible with the GIR.
		 */
		private Clutter.Margin fade_margins_value;

		public Clutter.Margin fade_margins {
			[CCode (cname = "gsr_st_scroll_view_fade_get_fade_margins_property")]
			get {
				return this.fade_margins_value;
			}
			[CCode (cname = "st_scroll_view_fade_set_fade_margins")]
			set {
				this.fade_margins_value = value;
			}
		}

		[CCode (cname = "st_scroll_view_fade_get_fade_margins")]
		public Clutter.Margin* get_fade_margins()
		{
			return &this.fade_margins_value;
		}
