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
			var handle = value as OLLMrpc.Live.Handle;
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
	 * {@code this.relay_attach()} (Helper-Actor + hooks).
	 *
	 * {@code Meta-BackgroundActor}: leave {@code rpc_lid == 0} for the leaf
	 * Helper construct. Stock ctor needs display+monitor; null-arg
	 * {@code Meta-BackgroundActor.new} is -32602. Do not walk to
	 * {@code Clutter-Actor} (wrong peer / double mint).
	 */
	construct {
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
			if (alias == "St-Widget") {
				this.relay_attach();
				return;
			}
			if (alias == "Meta-BackgroundActor") {
				return;
			}
			var response = GnomeShellRpc.call_value(alias + ".new", null);
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Handle).rpc_lid;
			GnomeShellRpc.GiStub.Runtime.register_handle(this);
			return;
		}
		GLib.error("lease construct: no Bin-registered ancestor for %s",
			this.get_type().name());
	}

	void relay_attach()
	{
		/* event: GJS vfunc_event often matches StWidget Class.event at
		 * attach — force-register (B3 panel path). */
		string[] always = { "event" };
		var overridden = GnomeShellRpc.GiStub.VfuncRelay.overridden(
			this.get_type(), "Clutter", "Actor", "StWidget", always);
		var response = GnomeShellRpc.call_value(
			"Helper-Actor.create", null,
			OLLMrpc.args("s", this.get_type().name()));
		this.rpc_lid = response.args.get(0).get_uint64();
		GnomeShellRpc.GiStub.Runtime.register_handle(this);
		foreach (var name in overridden) {
			var id = this.bind_vfunc(name);
			if (id == 0) {
				continue;
			}
			GnomeShellRpc.call_value(
				"Helper-Actor.add_hook", this,
				OLLMrpc.args("st", name, id));
		}
	}

	uint64 relay_get_preferred_width()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			float min = 0.0f, nat = 0.0f;
			GnomeShellRpc.GiStub.VfuncRelay.begin(this);
			try {
				this.get_preferred_width_vfunc(
					(float) call.args.get(1).get_double(),
					out min, out nat);
			} finally {
				GnomeShellRpc.GiStub.VfuncRelay.end();
			}
			if (GnomeShellRpc.GiStub.VfuncRelay.use_base) {
				var for_height = call.args.get(1).get_double();
				var response = GnomeShellRpc.call_value(
					"Helper-Actor.base_preferred_width", this,
					OLLMrpc.args("d", for_height));
				return OLLMrpc.args("dd",
					response.args.get(0).get_double(),
					response.args.get(1).get_double());
			}
			return OLLMrpc.args("dd", (double) min, (double) nat);
		});
	}

	uint64 relay_get_preferred_height()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			float min = 0.0f, nat = 0.0f;
			GnomeShellRpc.GiStub.VfuncRelay.begin(this);
			try {
				this.get_preferred_height_vfunc(
					(float) call.args.get(1).get_double(),
					out min, out nat);
			} finally {
				GnomeShellRpc.GiStub.VfuncRelay.end();
			}
			if (GnomeShellRpc.GiStub.VfuncRelay.use_base) {
				var for_width = call.args.get(1).get_double();
				var response = GnomeShellRpc.call_value(
					"Helper-Actor.base_preferred_height", this,
					OLLMrpc.args("d", for_width));
				return OLLMrpc.args("dd",
					response.args.get(0).get_double(),
					response.args.get(1).get_double());
			}
			return OLLMrpc.args("dd", (double) min, (double) nat);
		});
	}

	uint64 relay_allocate()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			var box = ActorBox();
			box.x1 = (float) call.args.get(1).get_double();
			box.y1 = (float) call.args.get(2).get_double();
			box.x2 = (float) call.args.get(3).get_double();
			box.y2 = (float) call.args.get(4).get_double();
			GnomeShellRpc.GiStub.VfuncRelay.begin(this);
			try {
				this.allocate_vfunc(box);
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
	 * Live.Hook args: actor lease, event type, x, y, button ({@code tiddu}).
	 * Reply: bool (EVENT_STOP = true).
	 */
	uint64 relay_event()
	{
		return GnomeShellRpc.GiStub.Runtime.callback_bind((call) => {
			var type = (EventType) call.args.get(1).get_int();
			var x = (float) call.args.get(2).get_double();
			var y = (float) call.args.get(3).get_double();
			var button = (uint32) call.args.get(4).get_uint();
			var ev = Event.from_local(type, x, y, button);
			GnomeShellRpc.GiStub.VfuncRelay.begin(this);
			bool stop = false;
			try {
				stop = this.event_vfunc(ev);
			} finally {
				GnomeShellRpc.GiStub.VfuncRelay.end();
			}
			if (GnomeShellRpc.GiStub.VfuncRelay.use_base) {
				return OLLMrpc.args("b", false);
			}
			return OLLMrpc.args("b", stop);
		});
	}

	public virtual void get_preferred_width(
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
		var response = GnomeShellRpc.call_value(
			"Clutter-Actor.get_preferred_width", this,
			OLLMrpc.args("f", (double) for_height));
		min_width_p = (float) response.args.get(0).get_float();
		natural_width_p = (float) response.args.get(1).get_float();
	}

	public virtual void get_preferred_height(
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
		var response = GnomeShellRpc.call_value(
			"Clutter-Actor.get_preferred_height", this,
			OLLMrpc.args("f", (double) for_width));
		min_height_p = (float) response.args.get(0).get_float();
		natural_height_p = (float) response.args.get(1).get_float();
	}

	public virtual void allocate(ActorBox box)
	{
		if (GnomeShellRpc.GiStub.VfuncRelay.hook_actor == this) {
			GnomeShellRpc.GiStub.VfuncRelay.use_base = true;
			return;
		}
		uint8[] data = new uint8[sizeof(ActorBox)];
		*((ActorBox*) data) = box;
		GnomeShellRpc.call_value(
			"Clutter-Actor.allocate", this,
			OLLMrpc.args("ay", new GLib.Bytes(data)));
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
	 * GIR pivot-point getter uses float OUTs — generator skips the property
	 * and we deny get/set_pivot_point (Vala would emit duplicate C symbols for
	 * the property accessors). Inline RPC for GJS construct literals.
	 */
	public Graphene.Point pivot_point {
		get {
			var response = GnomeShellRpc.call_value(
				"Clutter-Actor.get_pivot_point", this);
			float x = (float) response.args.get(0).get_float();
			float y = (float) response.args.get(1).get_float();
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
	 * Stock {@code clutter_actor_destroy} C ABI (method body denied —
	 * name clashes with GIR signal {@code destroy}, emitted by generator).
	 */
	[CCode (cname = "clutter_actor_destroy")]
	public void destroy_rpc()
	{
		GnomeShellRpc.call_value( "Clutter-Actor.destroy", this);
	}

	/**
	 * Generator gap: GIR getter is {@code is_visible}, no setter symbol
	 * (writable via {@code show}/{@code hide}). Denied generated prop; relay.
	 */
	public bool visible {
		get {
			return this.is_visible();
		}
		set {
			if (value) {
				this.show();
			} else {
				this.hide();
			}
		}
	}

	/**
	 * Generator gap: GIR {@code scale-x}/{@code scale-y} have no dedicated
	 * accessors (only {@code get_scale}/{@code set_scale}) — skipped. Relay
	 * like {@code opacity}/{@code scale_z}; set one axis preserves the other.
	 */
	public double scale_x {
		get {
			double sx;
			double sy;
			this.get_scale(out sx, out sy);
			return sx;
		}
		set {
			double sx;
			double sy;
			this.get_scale(out sx, out sy);
			this.set_scale(value, sy);
		}
	}

	public double scale_y {
		get {
			double sx;
			double sy;
			this.get_scale(out sx, out sy);
			return sy;
		}
		set {
			double sx;
			double sy;
			this.get_scale(out sx, out sy);
			this.set_scale(sx, value);
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
	 * client-owned — no {@code rpc_lid}. RPC only when the manager is a
	 * leased stock type ({@link BinLayout}, {@link BoxLayout}, …).
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
				/* GJS LayoutManager — local only; still run set_container vfunc. */
				if (previous != null && previous != value && previous.rpc_lid == 0) {
					previous.set_container(null);
				}
				value.set_container(this);
			}
		}
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
