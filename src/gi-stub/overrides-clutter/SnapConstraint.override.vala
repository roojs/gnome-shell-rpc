	/**
	 * GIR has {@code from-edge}/{@code to-edge} construct props, but the
	 * accessors are {@code get_edges}/{@code set_edges} (two OUTs / two INs) —
	 * not {@code get/set_from_edge}. The generator skips properties whose
	 * getter has OUT args, so GJS {@code new SnapConstraint({ from_edge, … })}
	 * would miss them. {@code source}/{@code offset} stay generated (real
	 * get/set).
	 */
	public SnapEdge from_edge { get; set construct; default = SnapEdge.top; }
	public SnapEdge to_edge { get; set construct; default = SnapEdge.top; }

	public void get_edges(out SnapEdge from_edge, out SnapEdge to_edge)
	{
		from_edge = this.from_edge;
		to_edge = this.to_edge;
	}

	public void set_edges(SnapEdge from_edge, SnapEdge to_edge)
	{
		this.from_edge = from_edge;
		this.to_edge = to_edge;
	}
