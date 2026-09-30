	/**
	 * Content = actor paint delegate. RPC when the Content has a lease
	 * (e.g. {@link Meta.BackgroundContent}); client-only Content (no
	 * {@code rpc_lid}) stays attached locally for GJS identity only.
	 */
	private Content? priv_content;

	public Content? content {
		get {
			if (this.priv_content != null) {
				return this.priv_content;
			}
			var response = GnomeShellRpc.call_value(
				"Clutter-Actor.get_content", this);
			if (response.retval.type() == GLib.Type.INVALID
					|| response.retval.get_object() == null) {
				return null;
			}
			return (Content) response.retval.get_object();
		}
		set {
			this.priv_content = value;
			if (value == null) {
				GnomeShellRpc.call_value(
					"Clutter-Actor.set_content", this,
					OLLMrpc.args("o", null));
				return;
			}
			var handle = value as OLLMrpc.Live.Interface;
			if (handle != null && handle.rpc_lid != 0) {
				GnomeShellRpc.call_value(
					"Clutter-Actor.set_content", this,
					OLLMrpc.args("o", value));
			}
		}
	}

	/**
	 * Lease like the generator parent-walk ({@code Actor.new} denied).
	 * First Bin-registered ancestor; {@code St-Widget} →
	 * {@code this.create_with_overrides()} (server actor, overrides included).
	 *
	 * {@code Meta-BackgroundActor}: leave {@code rpc_lid == 0} for the leaf
	 * Helper construct. Stock ctor needs display+monitor; null-arg
	 * {@code Meta-BackgroundActor.new} is -32602. Do not walk to
	 * {@code Clutter-Actor} (wrong peer / double mint).
	 */
	construct {
		this.signal_queue_relayout.connect(() => {
			var baseline = GLib.Type.from_name("StWidget");
			if (baseline != GLib.Type.INVALID
					&& OLLMrpc.Gi.vfunc_slot(this.get_type(), "Clutter", "Actor", "queue_relayout")
					!= OLLMrpc.Gi.vfunc_slot(baseline, "Clutter", "Actor", "queue_relayout")) {
				GnomeShellRpc.GiStub.vfunc_call_void(
					this, OLLMrpc.Gi.vfunc_offset("Clutter", "Actor", "queue_relayout"));
			}
		});

		if (this.rpc_lid != 0) {
			return;
		}
		var t = this.get_type();
		while (t != GLib.Type.INVALID) {
			if (OLLMrpc.Bin.gtype_to_alias == null
					|| !OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
				t = t.parent();
				continue;
			}
			var alias = OLLMrpc.Bin.gtype_to_alias.get(t);
			switch (alias) {
				case "Meta-BackgroundActor": // leaf Helper
				case "Clutter-Clone": // Clone.override new(source)
					return;
				case "St-Widget":
					this.create_with_overrides();
					this.signal_overrides(this.get_type());
					return;
				case "Clutter-Actor":
					/* Exact Actor → .new. GJS/Vala subclasses need Helper hooks. */
					if (this.get_type() != typeof(Actor)) {
						this.create_with_overrides();
						this.signal_overrides(this.get_type());
						return;
					}
					break;
				default:
					break;
			}
			var response = GnomeShellRpc.call_value(alias + ".new");
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Interface).rpc_lid;
			GnomeShellRpc.GiStub.Runtime.register_handle(this);
			this.signal_overrides(this.get_type());
			this.prop_batch_open = true;
			return;
		}
		GLib.error("lease construct: no Bin-registered ancestor for %s",
			this.get_type().name());
	}

	protected bool helper_attached;
	bool relayout_queued;
	/* Stock ClutterActor:visible default TRUE — the flag, not is_visible(). */
	bool actor_visible = true;
	double cached_scale_x = 1.0;
	double cached_scale_y = 1.0;
	string actor_name = "";
	bool name_known = false;

	/**
	 * Initial property sets, held until the first call that is
	 * not one of them.
	 */
	internal Gee.HashMap<string, GLib.Value?> prop_batch {
		get; set; default = new Gee.HashMap<string, GLib.Value?>();
	}

	internal bool prop_batch_open = false;

	void create_with_overrides()
	{
		GnomeShellRpc.GiStub.Runtime.hook_rows =
			new Gee.ArrayList<GnomeShellRpc.GiStub.Runtime.InvokeRow>();
		string[] always = {};
		var overridden = GnomeShellRpc.GiStub.VfuncRelay.overridden(
			this.get_type(), "Clutter", "Actor", "StWidget", always);
		string[] names = {};
		var vfunc_ids = new GLib.VariantBuilder(new GLib.VariantType("ai"));
		foreach (var name in overridden) {
			var vfunc_id = -1;
			var hook_id = this.bind_vfunc(name, out vfunc_id);
			if (hook_id == 0) {
				continue;
			}
			var called = GnomeShellRpc.GiStub.VfuncRelay.name_of(
				"Clutter", "Actor", vfunc_id);
			if (called == "") {
				var rows = GnomeShellRpc.GiStub.Runtime.hook_rows;
				rows.remove_at(rows.size - 1);
				continue;
			}
			names += called;
			vfunc_ids.add("i", vfunc_id);
		}
		var response = GnomeShellRpc.call_value("Helper-Actor.create", null,
			OLLMrpc.args("s", this.get_type().name()));
		this.rpc_lid = response.args.get(0).get_uint64();
		this.helper_attached = true;
		GnomeShellRpc.GiStub.Runtime.register_handle(this);
		if (names.length == 0) {
			GnomeShellRpc.GiStub.Runtime.hook_rows = null;
			this.prop_batch_open = true;
			return;
		}
		var hooks = GnomeShellRpc.call_value("Helper-Actor.add_hooks", this,
			OLLMrpc.args("Sv", names, vfunc_ids.end()));
		var ids = hooks.args.get(0).get_variant();
		if (GnomeShellRpc.GiStub.Runtime.handlers == null) {
			GnomeShellRpc.GiStub.Runtime.handlers = new Gee.HashMap<int,
				GnomeShellRpc.GiStub.Runtime.InvokeRow>();
		}
		var n = (int) ids.n_children();
		for (var i = 0; i < n; i++) {
			var id = ids.get_child_value(i).get_uint64();
			GnomeShellRpc.GiStub.Runtime.handlers.set((int) id,
				GnomeShellRpc.GiStub.Runtime.hook_rows.get(i));
		}
		GnomeShellRpc.GiStub.Runtime.hook_rows = null;
		this.prop_batch_open = true;
	}

	/**
	 * Subscribe each signal whose virtual this object replaced.
	 *
	 * Called from construct with this object's type. Calls itself
	 * on the parent first. A type with no alias is skipped. The
	 * leaf is not compared with itself.
	 *
	 * @param t parent type to compare against this object
	 */
	private void signal_overrides(GLib.Type t)
	{
		if (t == GLib.Type.INVALID) {
			return;
		}
		this.signal_overrides(t.parent());
		if (t == this.get_type()) {
			return;
		}
		if (OLLMrpc.Bin.gtype_to_alias == null) {
			return;
		}
		if (!OLLMrpc.Bin.gtype_to_alias.has_key(t)) {
			return;
		}
		var alias = OLLMrpc.Bin.gtype_to_alias.get(t);
		var dot = alias.index_of("-");
		if (dot < 0) {
			return;
		}
		var ns = alias.substring(0, dot);
		var class_name = alias.substring(dot + 1);
		var leaf = this.get_type();
		foreach (var name in OLLMrpc.Gi.vfunc_names(ns, class_name)) {
			var ours = OLLMrpc.Gi.vfunc_slot(leaf, ns, class_name, name);
			var plain = OLLMrpc.Gi.vfunc_slot(t, ns, class_name, name);
			if (ours == plain) {
				continue;
			}
			var signal_name = name.replace("_", "-");
			if (GLib.Signal.lookup(signal_name, leaf) == 0) {
				continue;
			}
			GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(this, signal_name);
		}
	}

	uint64 relay_get_preferred_width()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			float min = 0.0f, nat = 0.0f;
			GnomeShellRpc.GiStub.VfuncRelay.begin(this);
			try {
				GnomeShellRpc.GiStub.vfunc_call_preferred_size(
					this, OLLMrpc.Gi.vfunc_offset("Clutter", "Actor", "get_preferred_width"),
					(float) call.args.get(1).get_double(),
					out min, out nat);
			} finally {
				GnomeShellRpc.GiStub.VfuncRelay.end();
			}
			double out_min = min;
			double out_nat = nat;
			if (GnomeShellRpc.GiStub.VfuncRelay.use_base) {
				var for_height = call.args.get(1).get_double();
				var response = GnomeShellRpc.call_value(
					"Helper-Actor.base_preferred_width", this,
					OLLMrpc.args("d", for_height));
				out_min = response.args.get(0).get_double();
				out_nat = response.args.get(1).get_double();
			}
			/* A JS preferred-width that only scales the parent size
			 * reports 0 when that parent call returns 0. The layout
			 * manager still knows the child. DashItemContainer is that
			 * case: scale is 1, the button is ~48, the item was 0. */
			if (out_min == 0.0 && out_nat == 0.0) {
				var lm = this.priv_layout_manager;
				if (lm != null) {
					float lmin = 0.0f, lnat = 0.0f;
					lm.get_preferred_width(
						this, (float) call.args.get(1).get_double(),
						out lmin, out lnat);
					if (lmin != 0.0f || lnat != 0.0f) {
						out_min = lmin;
						out_nat = lnat;
					}
				}
			}
			return OLLMrpc.args("dd", out_min, out_nat);
		});
	}

	uint64 relay_get_preferred_height()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			float min = 0.0f, nat = 0.0f;
			GnomeShellRpc.GiStub.VfuncRelay.begin(this);
			try {
				GnomeShellRpc.GiStub.vfunc_call_preferred_size(
					this, OLLMrpc.Gi.vfunc_offset("Clutter", "Actor", "get_preferred_height"),
					(float) call.args.get(1).get_double(),
					out min, out nat);
			} finally {
				GnomeShellRpc.GiStub.VfuncRelay.end();
			}
			double out_min = min;
			double out_nat = nat;
			if (GnomeShellRpc.GiStub.VfuncRelay.use_base) {
				var for_width = call.args.get(1).get_double();
				var response = GnomeShellRpc.call_value(
					"Helper-Actor.base_preferred_height", this,
					OLLMrpc.args("d", for_width));
				out_min = response.args.get(0).get_double();
				out_nat = response.args.get(1).get_double();
			}
			if (out_min == 0.0 && out_nat == 0.0) {
				var lm = this.priv_layout_manager;
				if (lm != null) {
					float lmin = 0.0f, lnat = 0.0f;
					lm.get_preferred_height(
						this, (float) call.args.get(1).get_double(),
						out lmin, out lnat);
					if (lmin != 0.0f || lnat != 0.0f) {
						out_min = lmin;
						out_nat = lnat;
					}
				}
			}
			return OLLMrpc.args("dd", out_min, out_nat);
		});
	}

	uint64 relay_allocate()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			this.relayout_queued = false;
			var box = ActorBox();
			box.x1 = (float) call.args.get(1).get_double();
			box.y1 = (float) call.args.get(2).get_double();
			box.x2 = (float) call.args.get(3).get_double();
			box.y2 = (float) call.args.get(4).get_double();
			GnomeShellRpc.GiStub.VfuncRelay.begin(this);
			try {
				GnomeShellRpc.GiStub.vfunc_call_void_pointer(
					this, OLLMrpc.Gi.vfunc_offset("Clutter", "Actor", "allocate"),
					(void*) &box);
			} finally {
				GnomeShellRpc.GiStub.VfuncRelay.end();
			}
			if (GnomeShellRpc.GiStub.VfuncRelay.use_base) {
				return OLLMrpc.args("b", true);
			}
			return OLLMrpc.args("b", false);
		});
	}

	/**
	 * Live.Hook args: actor lease, event type, x, y, button, keyval
	 * ({@code tidduu}). Reply: bool (EVENT_STOP = true).
	 */
	uint64 relay_event()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			var type = (EventType) call.args.get(1).get_int();
			var x = (float) call.args.get(2).get_double();
			var y = (float) call.args.get(3).get_double();
			var button = (uint32) call.args.get(4).get_uint();
			var keyval = 0u;
			if (call.args.size > 5) {
				keyval = call.args.get(5).get_uint();
			}
			var ev = Event.from_local(type, x, y, button, 0, keyval);
			GnomeShellRpc.GiStub.VfuncRelay.begin(this);
			var baseline = GLib.Type.from_name("StWidget");
			var has_override = baseline != GLib.Type.INVALID
				&& OLLMrpc.Gi.vfunc_slot(this.get_type(), "Clutter", "Actor", "event")
				!= OLLMrpc.Gi.vfunc_slot(baseline, "Clutter", "Actor", "event");
			bool stop = false;
			try {
				if (has_override) {
					stop = GnomeShellRpc.GiStub.vfunc_call_bool_pointer(
						this, OLLMrpc.Gi.vfunc_offset("Clutter", "Actor", "event"),
						(void*) ev);
				} else {
					GnomeShellRpc.GiStub.VfuncRelay.use_base = true;
				}
			} finally {
				GnomeShellRpc.GiStub.VfuncRelay.end();
			}
			switch (type) {
				case EventType.key_press:
					GLib.Signal.emit_by_name(this, "key-press-event", ev);
					break;
				case EventType.key_release:
					GLib.Signal.emit_by_name(this, "key-release-event", ev);
					break;
				default:
					break;
			}
			if (GnomeShellRpc.GiStub.VfuncRelay.use_base) {
				return OLLMrpc.args("b", false);
			}
			return OLLMrpc.args("b", stop);
		});
	}

	/**
	 * Same pack as {@link relay_event}. Emit {@code captured-event} so
	 * GJS {@code connect()} runs (PopupMenuManager); then the vfunc
	 * (BoxPointer mute).
	 */
	uint64 relay_captured_event()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			var type = (EventType) call.args.get(1).get_int();
			var x = (float) call.args.get(2).get_double();
			var y = (float) call.args.get(3).get_double();
			var button = (uint32) call.args.get(4).get_uint();
			var keyval = 0u;
			if (call.args.size > 5) {
				keyval = call.args.get(5).get_uint();
			}
			var ev = Event.from_local(type, x, y, button, 0, keyval);
			bool stop = this.signal_captured_event(ev);
			var baseline = GLib.Type.from_name("StWidget");
			var has_override = baseline != GLib.Type.INVALID
				&& OLLMrpc.Gi.vfunc_slot(this.get_type(), "Clutter", "Actor", "captured_event")
				!= OLLMrpc.Gi.vfunc_slot(baseline, "Clutter", "Actor", "captured_event");
			GnomeShellRpc.GiStub.VfuncRelay.begin(this);
			try {
				if (has_override
						&& GnomeShellRpc.GiStub.vfunc_call_bool_pointer(
							this, OLLMrpc.Gi.vfunc_offset("Clutter", "Actor", "captured_event"),
							(void*) ev)) {
					stop = true;
				} else if (!has_override) {
					GnomeShellRpc.GiStub.VfuncRelay.use_base = true;
				}
			} finally {
				GnomeShellRpc.GiStub.VfuncRelay.end();
			}
			return OLLMrpc.args("b", stop);
		});
	}

	/* Not virtual — extra Class slots shift every St.* GIR offset (GJS
	 * then installs vfunc_clicked on style_changed). */
	public void get_preferred_width(
		float for_height,
		out float min_width_p,
		out float natural_width_p
	) {
		if (GnomeShellRpc.GiStub.VfuncRelay.hook_actor == this) {
			GnomeShellRpc.GiStub.VfuncRelay.use_base = true;
			min_width_p = 0.0f;
			natural_width_p = 0.0f;
			return;
		}
		var lm = this.priv_layout_manager;
		if (lm != null && lm.rpc_lid == 0) {
			lm.get_preferred_width_vfunc(
				this, for_height,
				out min_width_p, out natural_width_p);
			return;
		}
		var response = GnomeShellRpc.call_value(
			"Clutter-Actor.get_preferred_width", this,
			OLLMrpc.args("f", (double) for_height));
		min_width_p = (float) response.args.get(0).get_float();
		natural_width_p = (float) response.args.get(1).get_float();
	}

	public void get_preferred_height(
		float for_width,
		out float min_height_p,
		out float natural_height_p
	) {
		if (GnomeShellRpc.GiStub.VfuncRelay.hook_actor == this) {
			GnomeShellRpc.GiStub.VfuncRelay.use_base = true;
			min_height_p = 0.0f;
			natural_height_p = 0.0f;
			return;
		}
		var lm = this.priv_layout_manager;
		if (lm != null && lm.rpc_lid == 0) {
			lm.get_preferred_height_vfunc(
				this, for_width,
				out min_height_p, out natural_height_p);
			return;
		}
		var response = GnomeShellRpc.call_value(
			"Clutter-Actor.get_preferred_height", this,
			OLLMrpc.args("f", (double) for_width));
		min_height_p = (float) response.args.get(0).get_float();
		natural_height_p = (float) response.args.get(1).get_float();
	}

	/* Not virtual — Vala would put allocate on a Class slot GJS never uses. */
	public void allocate(ActorBox box)
	{
		if (GnomeShellRpc.GiStub.VfuncRelay.hook_actor == this) {
			GnomeShellRpc.GiStub.VfuncRelay.use_base = true;
			return;
		}
		this.allocation_priv = box;
		if (this.helper_attached) {
			uint8[] helper_data = new uint8[sizeof(ActorBox)];
			*((ActorBox*) helper_data) = box;
			GnomeShellRpc.call_value("Helper-Actor.allocate_public", this,
				OLLMrpc.args("ay", new GLib.Bytes(helper_data)));
			return;
		}
		var lm = this.priv_layout_manager;
		if (lm != null && lm.rpc_lid == 0) {
			lm.allocate_vfunc(this, box);
			return;
		}
		uint8[] data = new uint8[sizeof(ActorBox)];
		*((ActorBox*) data) = box;
		GnomeShellRpc.call_value(
			"Clutter-Actor.allocate", this,
			OLLMrpc.args("ay", new GLib.Bytes(data)));
	}

	/**
	 * Stock {@code clutter_actor_event}. Compact {@link Event} is not a
	 * wire type. Pack type / capture / coords / button / keyval / state.
	 * {@code Helper-Actor.deliver_event} calls {@code clutter_actor_event}.
	 */
	public bool event(Event? event, bool capture)
	{
		if (event == null) {
			return false;
		}
		var response = GnomeShellRpc.call_value(
			"Helper-Actor.deliver_event", this,
			OLLMrpc.args("ibddduu",
				(int) event.type(),
				capture,
				(double) event.x,
				(double) event.y,
				event.button,
				event.keyval,
				(uint) event.get_state()));
		return response.retval.get_boolean();
	}

	/**
	 * Stock-offset Class fallthrough ({@code allocate_vfunc} etc.). GJS
	 * replaces the Class slot; these run only when no JS override.
	 */
	protected void get_preferred_width_vfunc_fallback(
		float for_height,
		out float min_width_p,
		out float natural_width_p
	) {
		if (GnomeShellRpc.GiStub.VfuncRelay.hook_actor == this) {
			GnomeShellRpc.GiStub.VfuncRelay.use_base = true;
		}
		min_width_p = 0.0f;
		natural_width_p = 0.0f;
	}

	protected void get_preferred_height_vfunc_fallback(
		float for_width,
		out float min_height_p,
		out float natural_height_p
	) {
		if (GnomeShellRpc.GiStub.VfuncRelay.hook_actor == this) {
			GnomeShellRpc.GiStub.VfuncRelay.use_base = true;
		}
		min_height_p = 0.0f;
		natural_height_p = 0.0f;
	}

	protected void allocate_vfunc_fallback(ActorBox box)
	{
		if (GnomeShellRpc.GiStub.VfuncRelay.hook_actor == this) {
			GnomeShellRpc.GiStub.VfuncRelay.use_base = true;
		}
	}

	/**
	 * Generator requires these once {@code Actor.show}/{@code hide} are
	 * denied ({@code vfunc_fallback=hand}). The Class slot is renamed
	 * {@code show_vfunc}/{@code hide_vfunc} so the GIR method can keep
	 * the stock names. GJS calls the method (cache + RPC below); there
	 * is no client-side Clutter {@code clutter_actor_show} to chain to,
	 * and calling {@link show} from here would be a second path into
	 * the same relay. Empty = no JS override, nothing local to run.
	 */
	protected void show_vfunc_fallback()
	{
	}

	protected void hide_vfunc_fallback()
	{
	}

	/**
	 * Stock {@code clutter_actor_show}/{@code hide} — relay plus local
	 * {@link visible} flag so GJS {@code actor.show()} and
	 * {@code actor.visible} share one cached state. Not virtual: extra
	 * Class slots shift St.* GIR offsets (clicked vs style_changed).
	 */
	public void show()
	{
		this.actor_visible = true;
		GnomeShellRpc.call_value("Clutter-Actor.show", this);
	}

	public void hide()
	{
		this.actor_visible = false;
		GnomeShellRpc.call_value("Clutter-Actor.hide", this);
	}

	/**
	 * GIR pivot-point getter uses float OUTs — generator skips the property
	 * and we deny get/set_pivot_point (Vala would emit duplicate C symbols for
	 * the property accessors). Inline RPC for GJS construct literals.
	 */
	public Graphene.Point pivot_point {
		get {
			var response = GnomeShellRpc.call_value(
				"Clutter-Actor.get_pivot_point", this);
			var x = (float) response.args.get(0).get_float();
			var y = (float) response.args.get(1).get_float();
			Graphene.Point point = {};
			point.init(x, y);
			return point;
		}
		set {
			GnomeShellRpc.call_value(
				"Clutter-Actor.set_pivot_point", this,
				OLLMrpc.args("ff", (double) value.x, (double) value.y));
		}
	}
	/**
	 * Box for {@link allocation}. Setting it notifies {@code allocation}.
	 * Not a GIR property.
	 */
	/* valac 0.56 does not support gir_skip (Vala 0.57+). */
	// [CCode (gir_skip = true)]
	public ActorBox allocation_relay {
		get {
			return this.allocation_priv;
		}
		set {
			this.allocation_priv = value;
			this.notify_property("allocation");
		}
	}
	/* Not a GIR field. valac 0.56 does not support gir_skip (Vala 0.57+). */
	// [CCode (gir_skip = true)]
	ActorBox allocation_priv = ActorBox();

	/**
	 * GIR property is read-only. {@code notify::allocation-relay} writes
	 * {@link allocation_relay}. The store is {@link relay_allocation}.
	 */
	public ActorBox allocation {
		get {
			return this.allocation_priv;
		}
	}

	/**
	 * Weird one. The {@code allocation} property is read-only, so there is
	 * no property setter. Shell JavaScript still calls {@code set_allocation}.
	 * That is a separate GIR method, legal only inside {@code allocate}, and
	 * its C symbol is {@code clutter_actor_set_allocation}.
	 *
	 * This method is that symbol. Vala calls {@link relay_allocation}.
	 * {@code gir_skip} only keeps the Vala name out of a generated GIR.
	 * The stock GIR already exposes {@code set_allocation}.
	 */
	[CCode (cname = "clutter_actor_set_allocation", gir_skip = true)]
	public void relay_allocation(ActorBox box)
	{
		this.allocation_priv = box;
		uint8[] data = new uint8[sizeof(ActorBox)];
		*((ActorBox*) data) = box;
		GnomeShellRpc.call_value("Clutter-Actor.set_allocation", this,
			OLLMrpc.args("ay", new GLib.Bytes(data)));
	}

	/**
	 * Stock {@code clutter_actor_queue_relayout} — generator body denied so
	 * we can coalesce. Dash {@code notify::scale-x} calls this every set;
	 * a sync RPC each time re-enters Helper-Actor allocate. One RPC until
	 * allocate, like stock {@code needs_relayout}. No extra GObject signal.
	 * Not virtual — see {@link get_preferred_width}.
	 */
	public void queue_relayout()
	{
		if (this.relayout_queued) {
			return;
		}
		this.relayout_queued = true;
		if (GnomeShellRpc.GiStub.VfuncRelay.hook_actor == this) {
			return;
		}
		GnomeShellRpc.call_value("Clutter-Actor.queue_relayout", this);
	}

	/**
	 * GIR {@code ClutterActor:visible} getter/setter. Get is the cached
	 * flag; set calls {@link show}/{@link hide} (relay + cache). Not
	 * {@code is_visible()} — that walks mapped ancestors on the server.
	 */
	public bool visible {
		get {
			return this.actor_visible;
		}
		set {
			if (value == this.actor_visible) {
				return;
			}
			if (value) {
				this.show();
				return;
			}
			this.hide();
		}
	}

	/**
	 * Stock {@code clutter_actor_get_name} / {@code set_name}. First get
	 * fetches; after that layout/toString reads stay local.
	 */
	public string name {
		owned get {
			if (!this.name_known) {
				var response = GnomeShellRpc.call_value("Clutter-Actor.get_name", this);
				unowned string? s = response.retval.get_string();
				this.actor_name = s != null ? s.dup() : "";
				this.name_known = true;
			}
			return this.actor_name;
		}
		set {
			this.actor_name = value ?? "";
			this.name_known = true;
			GnomeShellRpc.call_value("Clutter-Actor.set_name", this,
				OLLMrpc.args("s", this.actor_name));
		}
	}

	public void get_scale(out double scale_x, out double scale_y)
	{
		scale_x = this.cached_scale_x;
		scale_y = this.cached_scale_y;
	}

	public void set_scale(double scale_x, double scale_y)
	{
		if (this.cached_scale_x == scale_x && this.cached_scale_y == scale_y) {
			return;
		}
		this.cached_scale_x = scale_x;
		this.cached_scale_y = scale_y;
		GnomeShellRpc.call_value(
			"Clutter-Actor.set_scale", this,
			OLLMrpc.args("dd", scale_x, scale_y));
	}

	/**
	 * Generator gap: GIR {@code scale-x}/{@code scale-y} have no dedicated
	 * accessors (only {@code get_scale}/{@code set_scale}) — skipped. Relay
	 * like {@code opacity}/{@code scale_z}; set one axis preserves the other.
	 */
	public double scale_x {
		get {
			return this.cached_scale_x;
		}
		set {
			this.set_scale(value, this.cached_scale_y);
		}
	}

	public double scale_y {
		get {
			return this.cached_scale_y;
		}
		set {
			this.set_scale(this.cached_scale_x, value);
		}
	}

	/**
	 * Generator gap: GIR {@code translation-*} have no dedicated accessors
	 * (only {@code get_translation}/{@code set_translation}). Generated
	 * props use {@code set_property} with wire {@code sf}; OLLMrpc pins
	 * {@code GValue*} as INVALID then copy → type-id-0 CRITICAL. Relay
	 * like {@code scale_x}; set one axis preserves the others.
	 */
	public float translation_x {
		get {
			float tx, ty, tz;
			this.get_translation(out tx, out ty, out tz);
			return tx;
		}
		set {
			float tx, ty, tz;
			this.get_translation(out tx, out ty, out tz);
			this.set_translation(value, ty, tz);
		}
	}

	public float translation_y {
		get {
			float tx, ty, tz;
			this.get_translation(out tx, out ty, out tz);
			return ty;
		}
		set {
			float tx, ty, tz;
			this.get_translation(out tx, out ty, out tz);
			this.set_translation(tx, value, tz);
		}
	}

	public float translation_z {
		get {
			float tx, ty, tz;
			this.get_translation(out tx, out ty, out tz);
			return tz;
		}
		set {
			float tx, ty, tz;
			this.get_translation(out tx, out ty, out tz);
			this.set_translation(tx, ty, value);
		}
	}

	/**
	 * GIR: write-only, not construct. Keep non-construct so GObject applies
	 * the setter after lease-on-construct ({@code rpc_lid}) — a construct
	 * flag runs {@code add_constraint} too early on {@code St.Widget}.
	 */
	public Constraint? constraints {
		set {
			if (value != null) {
				this.add_constraint(value);
			}
		}
	}

	/**
	 * GIR write-only {@code effect} (no setter symbol) — same timing as
	 * {@link constraints}. GJS: {@code new St.Viewport({ effect: … })}.
	 */
	public Effect? effect {
		set {
			if (value != null) {
				this.add_effect(value);
			}
		}
	}

	/**
	 * GIR write-only {@code actions} — same as {@link constraints}.
	 * GJS: {@code new St.Widget({ actions: clickAction })}.
	 */
	public Action? actions {
		set {
			if (value != null) {
				this.add_action(value);
			}
		}
	}

	/**
	 * GJS {@link LayoutManager} subclasses (WorkspaceLayout, …) are
	 * client-owned — no {@code rpc_lid}. Keep the compositor’s stock
	 * manager; GJS layout runs via {@code *_vfunc} on the client.
	 */
	private LayoutManager? priv_layout_manager;

	public LayoutManager? layout_manager {
		get {
			return this.priv_layout_manager;
		}
		set {
			var previous = this.priv_layout_manager;
			this.priv_layout_manager = value;
			if (value == null) {
				if (previous != null && previous.rpc_lid == 0) {
					previous.set_container(null);
				}
				/*
				 * GJS often writes layout_manager=null on construct while
				 * priv is still unset. RPCing that clears the compositor’s
				 * default manager (St.Bin → BinLayout) and yields
				 * CLUTTER_IS_LAYOUT_MANAGER on allocate. No prior client
				 * manager → nothing to clear on the wire.
				 */
				if (previous == null) {
					return;
				}
				GnomeShellRpc.call_value(
					"Clutter-Actor.set_layout_manager",
					this,
					OLLMrpc.args("o", null));
				return;
			}
			if (value.rpc_lid != 0) {
				GnomeShellRpc.call_value(
					"Clutter-Actor.set_layout_manager",
					this,
					OLLMrpc.args("o", value));
			} else {
				if (previous != null && previous != value && previous.rpc_lid == 0) {
					previous.set_container(null);
				}
				value.set_container(this);
				GnomeShellRpc.call_value("Clutter-Actor.set_layout_manager",
					this, OLLMrpc.args("o", value.create_server_manager()));
			}
		}
	}

	/**
	 * Stock {@code clutter_actor_get_transition}.
	 *
	 * Server returns the live Transition (implicit animation from easing +
	 * set). {@code ui/environment.js} {@code Actor.ease()} connects
	 * {@code stopped} for {@code onComplete}; without
	 * {@link GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe}, that
	 * signal never reaches the client and MessageTray never arms
	 * {@code NOTIFICATION_TIMEOUT}.
	 */
	public Transition? get_transition(string name)
	{
		var response = GnomeShellRpc.call_value(
			"Clutter-Actor.get_transition", this,
			OLLMrpc.args("s", name));
		if (response.retval.type() == GLib.Type.INVALID
				|| response.retval.get_object() == null) {
			return null;
		}
		var transition = (Transition) response.retval.get_object();
		GnomeShellRpc.GiStub.Runtime.ensure_signal_subscribe(
			transition, "stopped");
		return transition;
	}

	/**
	 * Stock {@code clutter_actor_get_effect}.
	 *
	 * The GIR also has a write-only {@code effect} property. Denying that
	 * property reserves its conventional accessor symbol, so the generated
	 * method is intentionally replaced here.
	 */
	public Effect? get_effect(string name)
	{
		var response = GnomeShellRpc.call_value("Clutter-Actor.get_effect", this,
			OLLMrpc.args("s", name));
		if (response.retval.type() == GLib.Type.INVALID
				|| response.retval.get_object() == null) {
			return null;
		}
		return (Effect) response.retval.get_object();
	}

	/**
	 * TEMPORARY — mock a11y only. GIR {@code get/set_accessible} denied;
	 * BarLevel's {@link St.GenericAccessible} has no {@code rpc_lid}. Undeny
	 * when server Atk peers are leased. Role / name / state stay RPC.
	 *
	 * Lazy-mint so GJS {@code get_accessible()} is never null (quickSettings
	 * {@code add_relationship}, etc.). Explicit set (GenericAccessible) wins.
	 */
	private Atk.Object? priv_accessible;

	public Atk.Object? accessible {
		get {
			if (this.priv_accessible == null) {
				this.priv_accessible = Atk.GObjectAccessible.for_object(this);
			}
			return this.priv_accessible;
		}
		set {
			this.priv_accessible = value;
		}
	}
