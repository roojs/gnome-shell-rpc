		public void show() {
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.show", this);
		}

		public void hide() {
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.hide", this);
		}

		public bool get_visible() {
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.is_visible", this);
			return response.args.get(0).get_boolean();
		}

		public new void set_position(float x, float y) {
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.set_position",
				this,
				OLLMrpc.args("ff", x, y));
		}

		public new void set_size(float width, float height) {
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.set_size",
				this,
				OLLMrpc.args("ff", width, height));
		}

		public new void get_position(out float x, out float y) {
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Clutter-Actor.get_position", this);
			x = (float) response.args.get(0).get_float();
			y = (float) response.args.get(1).get_float();
		}
