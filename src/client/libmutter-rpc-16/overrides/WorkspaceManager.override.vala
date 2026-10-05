		Gee.HashMap<int, Workspace>? workspaces_by_index;
		int cached_n_workspaces = -1;

		public int32 n_workspaces {
			[CCode (cname = "meta_workspace_manager_get_n_workspaces")]
			get {
				if (this.cached_n_workspaces >= 0) {
					return this.cached_n_workspaces;
				}
				var response = Gsr.Client.Rpc.call_value(
					"Meta-WorkspaceManager.get_n_workspaces", this);
				this.cached_n_workspaces = response.retval.get_int();
				return this.cached_n_workspaces;
			}
			/* Stock JS grows WorkspaceTracker._workspaces from
			 * notify::n-workspaces. A read-only property rejects that
			 * update, so remove_workspace is handed undefined. */
			set {
				this.cached_n_workspaces = value;
				this.workspaces_by_index = null;
			}
		}

		public Workspace? get_workspace_by_index(int32 index)
		{
			if (this.workspaces_by_index == null) {
				this.workspaces_by_index =
					new Gee.HashMap<int, Workspace>();
			}
			if (this.workspaces_by_index.has_key((int) index)) {
				return this.workspaces_by_index.get((int) index);
			}
			var response = Gsr.Client.Rpc.call_value(
				"Meta-WorkspaceManager.get_workspace_by_index", this,
				OLLMrpc.args("i", (int) index));
			if (response.retval.type() == GLib.Type.INVALID) {
				return null;
			}
			var ws = (Workspace) response.retval.get_object();
			this.workspaces_by_index.set((int) index, ws);
			return ws;
		}
