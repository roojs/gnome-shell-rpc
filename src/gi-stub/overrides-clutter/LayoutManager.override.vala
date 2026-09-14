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

	static construct {
		child_meta_quark = Quark.from_string(
			"gsr-clutter-layout-manager-child-meta");
	}

	[CCode (cname = "clutter_layout_manager_layout_changed")]
	public void layout_changed_invoke()
	{
		this.layout_changed();
	}

	public virtual void set_container(Actor? container)
	{
		if (this.rpc_lid == 0) {
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
