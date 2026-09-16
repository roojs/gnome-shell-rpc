/**
 * Gate: IconTheme.get_icon_sizes wire — int32 slab as {@link GLib.Bytes}
 * ({@code ay} / BOXED), not Variant {@code ai}.
 *
 * Matches Helper pack + client unpack for D2.3. Local StreamValue only —
 * no nested mutter / weston.
 *
 *   meson compile -C build icon-sizes-ay-gate
 *   timeout 5 ./build/tests/call-sync-repro/icon-sizes-ay-gate
 */

static GLib.Bytes pack_sizes(int[] sizes)
{
	var nbytes = sizes.length * (int) sizeof(int);
	var buf = new uint8[nbytes];
	if (nbytes > 0) {
		GLib.Memory.copy(buf, sizes, nbytes);
	}
	return new GLib.Bytes(buf);
}

/**
 * @param ok set false if retval is not Bytes
 */
static int[] unpack_sizes(GLib.Value retval, out bool ok)
{
	ok = false;
	if (retval.type() != typeof(GLib.Bytes)) {
		stderr.printf("FAIL unpack: type=%s want Bytes\n", retval.type().name());
		return {};
	}
	ok = true;
	var blob = (GLib.Bytes) retval.get_boxed();
	if (blob == null || blob.get_size() == 0) {
		return {};
	}
	var n = (int) (blob.get_size() / sizeof(int));
	var sizes = new int[n];
	GLib.Memory.copy(sizes, blob.get_data(), n * sizeof(int));
	return sizes;
}

static int roundtrip(int[] want) throws GLib.Error
{
	var packed = OLLMrpc.val("ay", pack_sizes(want));
	var mout = new MemoryOutputStream(null, GLib.realloc, GLib.free);
	var dout = new DataOutputStream(mout);
	var wctx = new OLLMrpc.Bin.Stream(null, dout);
	OLLMrpc.Bin.StreamValue.write(wctx, packed);
	dout.flush();

	unowned uint8[] data = mout.get_data();
	var nbytes = (size_t) mout.get_data_size();
	var bytes = new Bytes(data[0:nbytes]);
	var min = new MemoryInputStream.from_bytes(bytes);
	var din = new DataInputStream(min);
	var rctx = new OLLMrpc.Bin.Stream(din, null);
	var type_byte = din.read_byte();
	var got_val = OLLMrpc.Bin.StreamValue.read(rctx, type_byte);
	bool ok;
	var got = unpack_sizes(got_val, out ok);
	if (!ok) {
		return 1;
	}
	if (got.length != want.length) {
		stderr.printf("FAIL len got=%d want=%d\n", got.length, want.length);
		return 1;
	}
	for (var i = 0; i < want.length; i++) {
		if (got[i] != want[i]) {
			stderr.printf("FAIL [%d] got=%d want=%d\n", i, got[i], want[i]);
			return 1;
		}
	}
	stderr.printf("roundtrip ok n=%d\n", want.length);
	return 0;
}

int main(string[] args)
{
	try {
		if (roundtrip(new int[] { 16, 24, 32, 48 }) != 0) {
			return 1;
		}
		int[] empty = {};
		if (roundtrip(empty) != 0) {
			return 1;
		}
	} catch (GLib.Error e) {
		stderr.printf("FAIL icon-sizes-ay-gate: %s\n", e.message);
		return 1;
	}
	stderr.printf("PASS icon-sizes-ay-gate\n");
	return 0;
}
