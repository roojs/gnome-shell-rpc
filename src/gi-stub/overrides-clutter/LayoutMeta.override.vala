	/**
	 * Local child-meta wrapper for GJS {@link LayoutManager} subclasses
	 * (and any client-created meta). Construct-only manager/container/actor
	 * match stock LayoutMeta; getters stay local (no rpc_lid on GJS metas).
	 *
	 * Use properties only — do not also emit get_* methods (same C symbols).
	 */
	private weak LayoutManager? priv_manager;
	private weak Actor? priv_container;
	private weak Actor? priv_actor;

	public LayoutManager manager {
		get {
			return this.priv_manager;
		}
		set construct {
			this.priv_manager = value;
		}
	}

	public Actor container {
		get {
			return this.priv_container;
		}
		set construct {
			this.priv_container = value;
		}
	}

	public Actor actor {
		get {
			return this.priv_actor;
		}
		set construct {
			this.priv_actor = value;
		}
	}

	public bool is_for(LayoutManager manager, Actor container, Actor actor)
	{
		return this.priv_manager == manager
			&& this.priv_container == container
			&& this.priv_actor == actor;
	}
