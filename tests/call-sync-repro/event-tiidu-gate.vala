/**
 * Gate: measure_event wire shape {@code tiddu} (lease, type, x, y, button).
 *
 * Regression: {@code "tiidu"} is t-i-i-d-u (two ints) — coords never both
 * double; client {@code get_double} on arg[2] → HOLDS_DOUBLE CRITICAL.
 * Correct format is {@code "tiddu"}.
 *
 *   meson compile -C build event-tiidu-gate
 *   timeout 5 ./build/tests/call-sync-repro/event-tiidu-gate
 */

static int check_tiddu(Gee.ArrayList<GLib.Value?> args, string label)
{
	if (args.size != 5) {
		stderr.printf("FAIL %s: size=%d want 5\n", label, args.size);
		return 1;
	}
	stderr.printf("%s types: %s %s %s %s %s\n",
		label,
		args.get(0).type().name(), args.get(1).type().name(),
		args.get(2).type().name(), args.get(3).type().name(),
		args.get(4).type().name());
	if (!args.get(0).holds(typeof(uint64))
			|| !args.get(1).holds(typeof(int))
			|| !args.get(2).holds(typeof(double))
			|| !args.get(3).holds(typeof(double))
			|| !args.get(4).holds(typeof(uint))) {
		stderr.printf("FAIL %s: type mismatch (want t/i/d/d/u = tiddu)\n", label);
		return 1;
	}
	var x = args.get(2).get_double();
	var y = args.get(3).get_double();
	if (x != 12.5 || y != 34.25) {
		stderr.printf("FAIL %s: coords x=%g y=%g\n", label, x, y);
		return 1;
	}
	return 0;
}

/**
 * Pack → StreamValue write/read → unpack (same as Live.Invoke args on wire).
 */
static int roundtrip_bin(Gee.ArrayList<GLib.Value?> src) throws GLib.Error
{
	var mout = new MemoryOutputStream(null, GLib.realloc, GLib.free);
	var dout = new DataOutputStream(mout);
	var wctx = new OLLMrpc.Bin.Stream(null, dout);
	foreach (var v in src) {
		OLLMrpc.Bin.StreamValue.write(wctx, v);
	}
	dout.flush();
	unowned uint8[] data = mout.get_data();
	var nbytes = (size_t) mout.get_data_size();
	var bytes = new Bytes(data[0:nbytes]);
	var min = new MemoryInputStream.from_bytes(bytes);
	var din = new DataInputStream(min);
	var rctx = new OLLMrpc.Bin.Stream(din, null);
	var out_args = new Gee.ArrayList<GLib.Value?>();
	for (var i = 0; i < src.size; i++) {
		var type_byte = din.read_byte();
		out_args.add(OLLMrpc.Bin.StreamValue.read(rctx, type_byte));
	}
	return check_tiddu(out_args, "bin-roundtrip");
}

int main(string[] args)
{
	/* Prove the typo fails: tiidu → second slot after type is int not double. */
	var typo = OLLMrpc.args("tiidu",
		(uint64) 99, (int) 4, 12.5, 34.25, (uint) 1);
	if (typo.get(2).holds(typeof(double))) {
		stderr.printf("FAIL: typo tiidu unexpectedly has double at [2]\n");
		return 1;
	}
	stderr.printf("typo tiidu [2]=%s (expected not double)\n",
		typo.get(2).type().name());

	var packed = OLLMrpc.args("tiddu",
		(uint64) 99,
		(int) 4,
		12.5,
		34.25,
		(uint) 1);
	if (check_tiddu(packed, "args-pack") != 0) {
		return 1;
	}
	try {
		if (roundtrip_bin(packed) != 0) {
			return 1;
		}
	} catch (GLib.Error e) {
		stderr.printf("FAIL bin-roundtrip: %s\n", e.message);
		return 1;
	}
	stderr.printf("PASS event-tiidu-gate\n");
	return 0;
}
