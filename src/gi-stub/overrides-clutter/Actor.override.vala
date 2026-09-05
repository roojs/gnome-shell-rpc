	/**
	 * Client-local — GIR Content is not wireable; stock BackgroundActor
	 * attaches {@link Meta.BackgroundContent} here.
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

	/** GIR omits {@code visible} accessor; required for GJS construct literals. */
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
	 * Client-local — GIR has {@code get_accessible}/{@code set_accessible}
	 * (denied in Clutter.deny). Generator would RPC them; BarLevel's peer is
	 * a client-only {@link St.GenericAccessible} with no {@code rpc_lid}, so
	 * wire set would fail. Role / name / state stay on the leased actor RPC.
	 * Vala accessors match the GIR method names.
	 */
	public Atk.Object? accessible { get; set; }
