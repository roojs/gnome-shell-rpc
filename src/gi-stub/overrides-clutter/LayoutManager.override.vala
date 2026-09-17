	/**
	 * GJS {@link LayoutManager} subclasses (QuickSettingsLayout, …) have no
	 * {@code rpc_lid}. Child layout props and container wiring stay local —
	 * same idea as {@link Actor.layout_manager}. Leased stock managers RPC.
	 *
	 * {@code layout_changed} is a GIR **signal**. The RPC **method** of the
	 * same name is denied (Vala name clash). Stock C only emits the signal —
	 * export that symbol under a different Vala name for GJS.
	 */
	private static Quark child_meta_quark;
	internal LayoutManager? helper_peer;

	static construct {
		child_meta_quark = Quark.from_string("gsr-clutter-layout-manager-child-meta");
	}

	[CCode (cname = "clutter_layout_manager_layout_changed")]
	public void layout_changed_invoke()
	{
		this.layout_changed();
		if (this.helper_peer == null) {
			return;
		}
		GnomeShellRpc.call_value("Clutter-LayoutManager.layout_changed", this.helper_peer);
	}

	internal uint64 relay_get_preferred_width()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			float min = 0.0f, nat = 0.0f;
			var container = (Actor) call.args.get(0).get_object();
			this.get_preferred_width_vfunc(container,
				(float) call.args.get(1).get_double(),
				out min, out nat);
			return OLLMrpc.args("dd", (double) min, (double) nat);
		});
	}

	internal uint64 relay_get_preferred_height()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			float min = 0.0f, nat = 0.0f;
			var container = (Actor) call.args.get(0).get_object();
			this.get_preferred_height_vfunc(container,
				(float) call.args.get(1).get_double(),
				out min, out nat);
			GLib.debug("lm-relay preferred-height type=%s min=%g nat=%g for=%g container=%s visible=%s",
				this.get_type().name(), min, nat,
				call.args.get(1).get_double(),
				container.name != null ? container.name : container.get_type().name(),
				container.visible ? "1" : "0");
			return OLLMrpc.args("dd", (double) min, (double) nat);
		});
	}

	internal uint64 relay_allocate()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			var container = (Actor) call.args.get(0).get_object();
			var box = ActorBox();
			box.x1 = (float) call.args.get(1).get_double();
			box.y1 = (float) call.args.get(2).get_double();
			box.x2 = (float) call.args.get(3).get_double();
			box.y2 = (float) call.args.get(4).get_double();
			this.allocate_vfunc(container, box);
			return OLLMrpc.args("");
		});
	}

	internal LayoutManager ensure_helper_peer()
	{
		if (this.helper_peer != null) {
			return this.helper_peer;
		}
		var minted = GnomeShellRpc.call_value(
			"Helper-LayoutManager.create", null);
		var peer = (LayoutManager) GLib.Object.new(typeof(LayoutManager));
		peer.rpc_lid = minted.args.get(0).get_uint64();
		GnomeShellRpc.GiStub.Runtime.register_handle(peer);
		this.helper_peer = peer;
		var vfunc_id = -1;
		var hook_id = this.bind_vfunc("get_preferred_width", out vfunc_id);
		GnomeShellRpc.call_value("Helper-LayoutManager.add_hook", peer,
			OLLMrpc.args("it", vfunc_id, hook_id));
		hook_id = this.bind_vfunc("get_preferred_height", out vfunc_id);
		GnomeShellRpc.call_value("Helper-LayoutManager.add_hook", peer,
			OLLMrpc.args("it", vfunc_id, hook_id));
		hook_id = this.bind_vfunc("allocate", out vfunc_id);
		GnomeShellRpc.call_value("Helper-LayoutManager.add_hook", peer,
			OLLMrpc.args("it", vfunc_id, hook_id));
			
		return peer;
	}

	/**
	 * Base {@code allocate} / measure Class slots are the RPC wrappers.
	 * GJS overrides {@code *_vfunc}. {@code rpc_lid == 0} here is chain-up
	 * from JS ({@code super.allocate}) — no lease, no RPC.
	 */
	public virtual void get_preferred_width(
		Actor container,
		float for_height,
		out float min_width_p,
		out float nat_width_p
	) {
		if (this.rpc_lid == 0) {
			min_width_p = 0.0f;
			nat_width_p = 0.0f;
			return;
		}
		var response = GnomeShellRpc.call_value(
			"Clutter-LayoutManager.get_preferred_width", this,
			OLLMrpc.args("of", container, (double) for_height));
		min_width_p = (float) response.args.get(0).get_float();
		nat_width_p = (float) response.args.get(1).get_float();
	}

	public virtual void get_preferred_height(
		Actor container,
		float for_width,
		out float min_height_p,
		out float nat_height_p
	) {
		if (this.rpc_lid == 0) {
			min_height_p = 0.0f;
			nat_height_p = 0.0f;
			return;
		}
		var response = GnomeShellRpc.call_value(
			"Clutter-LayoutManager.get_preferred_height", this,
			OLLMrpc.args("of", container, (double) for_width));
		min_height_p = (float) response.args.get(0).get_float();
		nat_height_p = (float) response.args.get(1).get_float();
	}

	public virtual void allocate(Actor container, ActorBox allocation)
	{
		if (this.rpc_lid == 0) {
			this.allocate_vfunc(container, allocation);
			return;
		}
		GLib.Bytes allocation_bytes;
		uint8[] _allocation_data = new uint8[sizeof(ActorBox)];
		*((ActorBox*) _allocation_data) = allocation;
		allocation_bytes = new GLib.Bytes(_allocation_data);
		GnomeShellRpc.call_value(
			"Clutter-LayoutManager.allocate", this,
			OLLMrpc.args("oay", container, allocation_bytes));
	}

	public virtual void set_container(Actor? container)
	{
		if (this.rpc_lid == 0) {
			/* Stock clutter_layout_manager_set_container → Class slot.
			 * GJS WorkspaceLayout fills _workarea only in vfunc_set_container. */
			this.set_container_vfunc(container);
			return;
		}
		GnomeShellRpc.call_value(
			"Clutter-LayoutManager.set_container",
			this,
			OLLMrpc.args("o", container));
	}

	public LayoutMeta? get_child_meta(Actor container, Actor actor)
	{
		if (this.rpc_lid != 0) {
			var response = GnomeShellRpc.call_value(
				"Clutter-LayoutManager.get_child_meta",
				this,
				OLLMrpc.args("oo", container, actor));
			if (response.retval.type() == GLib.Type.INVALID) {
				return null;
			}
			return (LayoutMeta) response.retval.get_object();
		}
		return this.ensure_local_child_meta(container, actor);
	}

	public void child_set_property(
		Actor container,
		Actor actor,
		string property_name,
		GLib.Value value
	) {
		if (this.rpc_lid != 0) {
			GLib.Bytes value_bytes;
			uint8[] value_data = new uint8[sizeof(GLib.Value)];
			*((GLib.Value*) value_data) = value;
			value_bytes = new GLib.Bytes(value_data);
			GnomeShellRpc.call_value(
				"Clutter-LayoutManager.child_set_property",
				this,
				OLLMrpc.args("oosay", container, actor, property_name, value_bytes));
			return;
		}
		var meta = this.ensure_local_child_meta(container, actor);
		if (meta == null) {
			GLib.warning(
				"Layout managers of type '%s' do not support layout metadata",
				this.get_type().name());
			return;
		}
		var pspec = ((GLib.Object) meta).get_class().find_property(property_name);
		if (pspec == null) {
			GLib.warning(
				"Layout managers of type '%s' have no layout property named '%s'",
				this.get_type().name(), property_name);
			return;
		}
		((GLib.Object) meta).set_property(property_name, value);
	}

	public void child_get_property(
		Actor container,
		Actor actor,
		string property_name,
		GLib.Value value
	) {
		if (this.rpc_lid != 0) {
			GLib.Bytes value_bytes;
			uint8[] value_data = new uint8[sizeof(GLib.Value)];
			*((GLib.Value*) value_data) = value;
			value_bytes = new GLib.Bytes(value_data);
			GnomeShellRpc.call_value(
				"Clutter-LayoutManager.child_get_property",
				this,
				OLLMrpc.args("oosay", container, actor, property_name, value_bytes));
			return;
		}
		var meta = this.ensure_local_child_meta(container, actor);
		if (meta == null) {
			return;
		}
		GLib.Value tmp = value;
		((GLib.Object) meta).get_property(property_name, ref tmp);
		value = tmp;
	}

	public GLib.ParamSpec? find_child_property(string name)
	{
		if (this.rpc_lid != 0) {
			var response = GnomeShellRpc.call_value(
				"Clutter-LayoutManager.find_child_property",
				this,
				OLLMrpc.args("s", name));
			if (response.retval.type() == GLib.Type.INVALID) {
				return null;
			}
			return (GLib.ParamSpec) response.retval.get_object();
		}
		var meta_type = this.get_child_meta_type();
		if (meta_type == Type.INVALID || meta_type == 0) {
			return null;
		}
		var klass = (ObjectClass) meta_type.class_ref();
		return klass.find_property(name);
	}

	private LayoutMeta? ensure_local_child_meta(Actor container, Actor actor)
	{
		var existing = actor.get_qdata<LayoutMeta>(child_meta_quark);
		if (existing != null && existing.is_for(this, container, actor)) {
			return existing;
		}
		var meta_type = this.get_child_meta_type();
		if (meta_type == Type.INVALID || meta_type == 0) {
			return null;
		}
		if (!meta_type.is_a(typeof(LayoutMeta))) {
			GLib.warning(
				"get_child_meta_type for %s is not a LayoutMeta (%s)",
				this.get_type().name(), meta_type.name());
			return null;
		}
		var meta = (LayoutMeta) GLib.Object.new(
			meta_type,
			"manager", this,
			"container", container,
			"actor", actor);
		meta.ref();
		actor.set_qdata_full(child_meta_quark, meta, (d) => {
			((GLib.Object) d).unref();
		});
		return meta;
	}
