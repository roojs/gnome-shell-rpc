	/**
	 * Content = actor paint delegate. RPC when the Content has a lease
	 * (e.g. {@link Meta.BackgroundContent}); client-only Content (no
	 * {@code rpc_lid}) stays attached locally for GJS identity only.
	 */
	private Content? priv_content;

	/**
	 * While set, preferred/allocate came from a Helper-Actor hook. Vala
	 * path (no JS vfunc) answers with a chain sentinel — server calls
	 * base locally (no nested {@code call_sync}). JS vfuncs never hit
	 * these methods unless they {@code super}.
	 */
	private static Actor? layout_relay_target;
	private static bool layout_relay_chain;

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
	 * {@link mint_layout_relay} (Helper-Actor + hooks).
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
				this.mint_layout_relay();
				return;
			}
			var response = GnomeShellRpc.call_value(alias + ".new", null);
			this.rpc_lid =
				(response.retval.get_object() as OLLMrpc.Live.Handle).rpc_lid;
			return;
		}
		GLib.error("lease construct: no Bin-registered ancestor for %s",
			this.get_type().name());
	}

	public virtual void get_preferred_width(
		float for_height,
		out float min_width_p,
		out float natural_width_p
	) {
		if (Actor.layout_relay_target == this) {
			Actor.layout_relay_chain = true;
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
		if (Actor.layout_relay_target == this) {
			Actor.layout_relay_chain = true;
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
		if (Actor.layout_relay_target == this) {
			Actor.layout_relay_chain = true;
			return;
		}
		uint8[] data = new uint8[sizeof(ActorBox)];
		*((ActorBox*) data) = box;
		GnomeShellRpc.call_value(
			"Clutter-Actor.allocate", this,
			OLLMrpc.args("ay", new GLib.Bytes(data)));
	}

	/**
	 * Mint Helper-Actor with preferred/allocate hooks. Callbacks run JS
	 * vfuncs when present; Vala fallthrough sets {@link layout_relay_chain}
	 * so the server bases without a nested chain RPC.
	 */
	public void mint_layout_relay()
	{
		var self = this;
		var preferred_width_id = GnomeShellRpc.GiStub.Runtime.callback_bind(
			(call) => {
				float min = 0.0f, nat = 0.0f;
				Actor.layout_relay_chain = false;
				Actor.layout_relay_target = self;
				try {
					self.get_preferred_width(
						(float) call.args.get(1).get_double(),
						out min, out nat);
				} finally {
					Actor.layout_relay_target = null;
				}
				var chain = Actor.layout_relay_chain;
				GLib.message(
					"DBG layout_relay preferred_width type=%s name=%s chain=%s min=%.1f nat=%.1f",
					self.get_type().name(),
					self.get_name() ?? "(null)",
					chain.to_string(), min, nat);
				if (chain) {
					return null;
				}
				return OLLMrpc.args("dd", (double) min, (double) nat);
			});
		var preferred_height_id = GnomeShellRpc.GiStub.Runtime.callback_bind(
			(call) => {
				float min = 0.0f, nat = 0.0f;
				Actor.layout_relay_chain = false;
				Actor.layout_relay_target = self;
				try {
					self.get_preferred_height(
						(float) call.args.get(1).get_double(),
						out min, out nat);
				} finally {
					Actor.layout_relay_target = null;
				}
				var chain = Actor.layout_relay_chain;
				GLib.message(
					"DBG layout_relay preferred_height type=%s name=%s chain=%s min=%.1f nat=%.1f",
					self.get_type().name(),
					self.get_name() ?? "(null)",
					chain.to_string(), min, nat);
				if (chain) {
					return null;
				}
				return OLLMrpc.args("dd", (double) min, (double) nat);
			});
		var allocate_id = GnomeShellRpc.GiStub.Runtime.callback_bind(
			(call) => {
				var box = ActorBox();
				box.x1 = (float) call.args.get(1).get_double();
				box.y1 = (float) call.args.get(2).get_double();
				box.x2 = (float) call.args.get(3).get_double();
				box.y2 = (float) call.args.get(4).get_double();
				Actor.layout_relay_chain = false;
				Actor.layout_relay_target = self;
				try {
					self.allocate(box);
				} finally {
					Actor.layout_relay_target = null;
				}
				var chain = Actor.layout_relay_chain;
				GLib.message(
					"DBG layout_relay allocate type=%s name=%s chain=%s box=(%.1f,%.1f)-(%.1f,%.1f)",
					self.get_type().name(),
					self.get_name() ?? "(null)",
					chain.to_string(),
					box.x1, box.y1, box.x2, box.y2);
				if (chain) {
					return OLLMrpc.args("b", true);
				}
				return OLLMrpc.args("b", false);
			});
		var response = GnomeShellRpc.call_value(
			"Helper-Actor.create", null,
			OLLMrpc.args("ttt",
				preferred_width_id, preferred_height_id, allocate_id));
		this.rpc_lid = response.args.get(0).get_uint64();
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
			this.priv_layout_manager = value;
			if (value == null) {
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
