		/**
		 * Local geometry — GJS {@code MonitorConstraint.vfunc_update_allocation}
		 * calls {@code actorBox.init_rect}; no RPC.
		 */
		public void init_rect(float x, float y, float width, float height)
		{
			this.x1 = x;
			this.y1 = y;
			this.x2 = x + width;
			this.y2 = y + height;
		}
