		/**
		 * Stock {@code meta_selection_source_memory_new}. Payload crosses as
		 * {@link GLib.Bytes} on {@code ay}; compositor builds the real source.
		 */
		public SelectionSourceMemory(string mimetype, GLib.Bytes content)
			throws GLib.Error
		{
			Object();
			var response = GnomeShellRpc.GiStub.Runtime.call_values(
				"Helper-SelectionSourceMemory.create", null,
				OLLMrpc.args("say", mimetype, content));
			var stub = (SelectionSourceMemory) response.retval.get_object();
			this.rpc_lid = stub.rpc_lid;
		}
