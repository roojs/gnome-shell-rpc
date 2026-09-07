		/**
		 * Local geometry helpers — {@code ActorBox} is a client-side struct
		 * (no {@code rpc_lid}). Deny generated error stubs; field math only.
		 */
		public void init_rect(float x, float y, float width, float height)
		{
			this.x1 = x;
			this.y1 = y;
			this.x2 = x + width;
			this.y2 = y + height;
		}

		public ActorBox init(float x_1, float y_1, float x_2, float y_2)
		{
			this.x1 = x_1;
			this.y1 = y_1;
			this.x2 = x_2;
			this.y2 = y_2;
			return this;
		}

		public void set_origin(float x, float y)
		{
			float w = this.x2 - this.x1;
			float h = this.y2 - this.y1;
			this.x1 = x;
			this.y1 = y;
			this.x2 = x + w;
			this.y2 = y + h;
		}

		public void set_size(float width, float height)
		{
			this.x2 = this.x1 + width;
			this.y2 = this.y1 + height;
		}

		public void get_origin(out float x, out float y)
		{
			x = this.x1;
			y = this.y1;
		}

		public void get_size(out float width, out float height)
		{
			width = this.x2 - this.x1;
			height = this.y2 - this.y1;
		}

		public float get_x()
		{
			return this.x1;
		}

		public float get_y()
		{
			return this.y1;
		}

		public float get_width()
		{
			return this.x2 - this.x1;
		}

		public float get_height()
		{
			return this.y2 - this.y1;
		}

		public float get_area()
		{
			return this.get_width() * this.get_height();
		}

		public bool contains(float x, float y)
		{
			return x >= this.x1 && x < this.x2 && y >= this.y1 && y < this.y2;
		}

		public bool equal(ActorBox box_b)
		{
			return this.x1 == box_b.x1 && this.y1 == box_b.y1
				&& this.x2 == box_b.x2 && this.y2 == box_b.y2;
		}

		public bool is_initialized()
		{
			return !(this.x1 == 0 && this.y1 == 0 && this.x2 == 0 && this.y2 == 0);
		}

		public void scale(float scale)
		{
			this.x1 *= scale;
			this.y1 *= scale;
			this.x2 *= scale;
			this.y2 *= scale;
		}

		public void interpolate(ActorBox final, double progress, out ActorBox result)
		{
			float t = (float) progress;
			result = {};
			result.x1 = this.x1 + (final.x1 - this.x1) * t;
			result.y1 = this.y1 + (final.y1 - this.y1) * t;
			result.x2 = this.x2 + (final.x2 - this.x2) * t;
			result.y2 = this.y2 + (final.y2 - this.y2) * t;
		}

		public void @union(ActorBox b, out ActorBox result)
		{
			result = {};
			result.x1 = this.x1 < b.x1 ? this.x1 : b.x1;
			result.y1 = this.y1 < b.y1 ? this.y1 : b.y1;
			result.x2 = this.x2 > b.x2 ? this.x2 : b.x2;
			result.y2 = this.y2 > b.y2 ? this.y2 : b.y2;
		}
