/**
 * Gate: generated {@link OLLMrpc.Bin.TypeOverride.pack} is one
 * {@link GLib.Bytes} of {@code sizeof} the record.
 *
 * Client and server compile the same generated file, so these lengths
 * are the lengths both sides use.
 *
 *   meson compile -C build tests/boxed-pack-gate/boxed-pack-gate
 *   ./build/tests/boxed-pack-gate/boxed-pack-gate
 */
class Gate : GLib.Object
{
	public void run()
	{
		this.sized(
			new Gsr.Boxed.GrapheneSizeOverride(),
			typeof(Graphene.Size),
			8,
			this.size_value()
		);
		this.sized(
			new Gsr.Boxed.ClutterMarginOverride(),
			typeof(Clutter.Margin),
			16,
			this.margin_value()
		);
		var empty = new Gsr.Boxed.ClutterEventSequenceOverride();
		var none = GLib.Value(typeof(Clutter.EventSequence));
		var fields = empty.pack(none);
		if (fields.size != 0) {
			GLib.error(
				"Clutter.EventSequence packed %d fields, expected an empty list",
				fields.size
			);
		}
	}

	/**
	 * @param over the generated override
	 * @param type the GType both sides pack
	 * @param n expected image length
	 * @param src a non-null record
	 */
	private void sized(
		OLLMrpc.Bin.TypeOverride over,
		GLib.Type type,
		int n,
		GLib.Value src
	)
	{
		if ((int) sizeof(Graphene.Size) != 8 && type == typeof(Graphene.Size)) {
			GLib.error("sizeof(Graphene.Size) is %d, expected 8", (int) sizeof(Graphene.Size));
		}
		if ((int) sizeof(Clutter.Margin) != 16 && type == typeof(Clutter.Margin)) {
			GLib.error("sizeof(Clutter.Margin) is %d, expected 16", (int) sizeof(Clutter.Margin));
		}
		var filled = this.image(over, src, n);
		if (filled[0] == 0 && filled[1] == 0 && filled[2] == 0 && filled[3] == 0) {
			GLib.error("%s packed zeros for a non-null record", type.name());
		}
		var blank = GLib.Value(type);
		var zeros = this.image(over, blank, n);
		for (var i = 0; i < zeros.length; i++) {
			if (zeros[i] != 0) {
				GLib.error("%s null pack byte %d is %u", type.name(), i, zeros[i]);
			}
		}
	}

	/**
	 * @param over the generated override
	 * @param src the record value
	 * @param n expected image length
	 * @return the packed image
	 */
	private uint8[] image(OLLMrpc.Bin.TypeOverride over, GLib.Value src, int n)
	{
		var fields = over.pack(src);
		if (fields.size != 1) {
			GLib.error("pack returned %d fields, expected 1", fields.size);
		}
		var blob = (GLib.Bytes) fields.get(0).get_boxed();
		if ((int) blob.get_size() != n) {
			GLib.error(
				"packed %u bytes, expected %d",
				(uint) blob.get_size(),
				n
			);
		}
		return blob.get_data();
	}

	private GLib.Value size_value()
	{
		var size = Graphene.Size();
		size.init(1, 2);
		var v = GLib.Value(typeof(Graphene.Size));
		v.set_boxed(&size);
		return v;
	}

	private GLib.Value margin_value()
	{
		var margin = Clutter.Margin();
		margin.left = 1;
		margin.right = 2;
		margin.top = 3;
		margin.bottom = 4;
		var v = GLib.Value(typeof(Clutter.Margin));
		v.set_boxed(&margin);
		return v;
	}
}

int main()
{
	var gate = new Gate();
	gate.run();
	stdout.printf("PASS boxed pack\n");
	return 0;
}
