		/**
		 * Walk {@code root}'s children via leased Actor RPC
		 * ({@link Actor.first_child} / {@link Actor.get_next_sibling}).
		 * {@code dummy1} = root, {@code dummy2} = current (null = before first),
		 * {@code dummy3} = non-zero while valid.
		 */
		public void init(Actor root)
		{
			this.dummy1 = (void*) root;
			this.dummy2 = null;
			this.dummy3 = 1;
		}

		public bool is_valid()
		{
			return this.dummy3 != 0 && this.dummy1 != null;
		}

		public bool next(out Actor child)
		{
			child = null;
			if (!this.is_valid()) {
				return false;
			}
			var root = (Actor) this.dummy1;
			Actor? cur = (Actor?) this.dummy2;
			Actor? n;
			if (cur == null) {
				n = root.first_child;
			} else {
				n = cur.get_next_sibling();
			}
			this.dummy2 = (void*) n;
			if (n == null) {
				return false;
			}
			child = n;
			return true;
		}

		public bool prev(out Actor child)
		{
			child = null;
			if (!this.is_valid() || this.dummy2 == null) {
				return false;
			}
			var p = ((Actor) this.dummy2).get_previous_sibling();
			this.dummy2 = (void*) p;
			if (p == null) {
				return false;
			}
			child = p;
			return true;
		}

		public void remove()
		{
			if (!this.is_valid() || this.dummy2 == null) {
				return;
			}
			var cur = (Actor) this.dummy2;
			var next = cur.get_next_sibling();
			var parent = cur.get_parent();
			if (parent != null) {
				parent.remove_child(cur);
			}
			this.dummy2 = (void*) next;
		}

		public void destroy()
		{
			this.dummy1 = null;
			this.dummy2 = null;
			this.dummy3 = 0;
		}
