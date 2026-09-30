		Gee.HashMap<int, Workspace>? workspaces_by_index;
		int cached_n_workspaces = -1;

		public int32 n_workspaces {
			[CCode (cname = "meta_workspace_manager_get_n_workspaces")]
			get {
				if (this.cached_n_workspaces >= 0) {
					return this.cached_n_workspaces;
				}
				var response = GnomeShellRpc.call_value(
					"Meta-WorkspaceManager.get_n_workspaces", this);
				this.cached_n_workspaces = response.retval.get_int();
				return this.cached_n_workspaces;
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
			var response = GnomeShellRpc.call_value(
				"Meta-WorkspaceManager.get_workspace_by_index", this,
				OLLMrpc.args("i", (int) index));
			if (response.retval.type() == GLib.Type.INVALID) {
				return null;
			}
			var ws = (Workspace) response.retval.get_object();
			this.workspaces_by_index.set((int) index, ws);
			return ws;
		}
