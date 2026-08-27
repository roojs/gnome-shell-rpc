		public void foreach_transient(WindowForeachFunc func) {
			var callback_id = GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
				var win = (Window) GnomeShellRpc.GiStub.Runtime.client.proxies.get(
					(int) call.args.get(0).get_uint64());
				return OLLMrpc.args("b", func(win, null));
			});
			GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-Window.foreach_transient", this,
				OLLMrpc.args("t", callback_id));
		}
