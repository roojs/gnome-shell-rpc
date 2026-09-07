	/**
	 * TEMPORARY — MUST IMPLEMENT on wire for live paint.
	 * {@link Content} is the actor paint delegate (not metadata). Denied
	 * {@code get/set_content} so nested mock can attach
	 * {@link Meta.BackgroundContent} client-locally; undeny + RPC when the
	 * compositor must own Content.
	 */
	public Content? content { get; set; }

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
	 */
	public Atk.Object? accessible { get; set; }
