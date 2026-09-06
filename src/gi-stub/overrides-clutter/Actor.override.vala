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
	 * Generator gap: GIR getter is {@code is_visible}, and construct default
	 * is needed for GJS literals — deny generated {@code visible}, hand this.
	 */
	public bool visible { get; set construct; default = true; }

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
