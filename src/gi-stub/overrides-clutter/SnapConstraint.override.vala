	/**
	 * GIR has {@code from-edge}/{@code to-edge} construct props, but the
	 * accessors are {@code get_edges}/{@code set_edges} (two OUTs / two INs) —
	 * not {@code get/set_from_edge}. The generator skips properties whose
	 * getter has OUT args, so GJS {@code new SnapConstraint({ from_edge, … })}
	 * would miss them. {@code source}/{@code offset} stay generated (real
	 * get/set).
	 *
	 * Lease: {@code Clutter-SnapConstraint.new} → real mutter SnapConstraint.
	 * Edges are construct — push via {@code set_edges} after mint.
	 */
	private SnapEdge priv_from_edge = SnapEdge.top;
	private SnapEdge priv_to_edge = SnapEdge.top;

	public SnapEdge from_edge {
		get {
			return this.priv_from_edge;
		}
		set construct {
			this.priv_from_edge = value;
			this.sync_edges();
		}
	}

	public SnapEdge to_edge {
		get {
			return this.priv_to_edge;
		}
		set construct {
			this.priv_to_edge = value;
			this.sync_edges();
		}
	}

	protected override void mint_server_lease()
	{
		var response = GnomeShellRpc.call_value(
			"Clutter-SnapConstraint.new", null);
		this.rpc_lid = response.args.get(0).get_uint64();
		this.sync_edges();
	}

	public void get_edges(out SnapEdge from_edge, out SnapEdge to_edge)
	{
		from_edge = this.priv_from_edge;
		to_edge = this.priv_to_edge;
	}

	public void set_edges(SnapEdge from_edge, SnapEdge to_edge)
	{
		this.priv_from_edge = from_edge;
		this.priv_to_edge = to_edge;
		this.sync_edges();
	}

	private void sync_edges()
	{
		if (this.rpc_lid == 0) {
			return;
		}
		GnomeShellRpc.call_value(
			"Clutter-SnapConstraint.set_edges", this,
			OLLMrpc.args("ii",
				(int) this.priv_from_edge, (int) this.priv_to_edge));
	}
