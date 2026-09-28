/**
 * Gate: a null GObject in {@link OLLMrpc.Notification.args} must travel
 * as uint64 lease 0, the same form {@link GnomeShellRpc.call_value} uses
 * for a null IN object.
 *
 * An explicit uint64 0 parses. A raw null {@link GLib.Object} does not:
 * {@link OLLMrpc.Bin.StreamValue.write} emits no type byte, the args count
 * stays 1, and the next property tag is read as a type
 * ({@code unsupported wire type 0x00}). That is the calendar-close
 * {@code notify::key-focus} death. The first notification only registers
 * property names, as menu open does.
 *
 *   meson compile -C build tests/call-sync-repro/null-object-arg-gate
 *   timeout 5 ./build/tests/call-sync-repro/null-object-arg-gate
 */

static OLLMrpc.Notification parse_one(OLLMrpc.Bin.Stream rctx) throws GLib.Error
{
	var obj = rctx.parse();
	var note = obj as OLLMrpc.Notification;
	if (note == null) {
		error("parsed %s, want Notification", obj.get_type().name());
	}
	return note;
}

static bool write_note(OLLMrpc.Bin.Stream wctx, OLLMrpc.Notification note, string label)
{
	try {
		wctx.write(note);
	} catch (GLib.Error e) {
		stderr.printf("FAIL null-object-arg-gate: write %s: %s\n", label, e.message);
		return false;
	}
	return true;
}

int main()
{
	OLLMrpc.Notification.rpc_register();

	var mout = new MemoryOutputStream(null, GLib.realloc, GLib.free);
	var dout = new DataOutputStream(mout);
	var wctx = new OLLMrpc.Bin.Stream(null, dout);

	var opened = new OLLMrpc.Notification() {
		method = "notify::key-focus",
		id = 1
	};
	opened.args.add(OLLMrpc.val("b", true));
	if (!write_note(wctx, opened, "open")) {
		return 1;
	}

	var as_int = new OLLMrpc.Notification() {
		method = "notify::key-focus",
		id = 2
	};
	as_int.args.add(OLLMrpc.val("t", (uint64) 0));
	if (!write_note(wctx, as_int, "lease-0")) {
		return 1;
	}

	var closed = new OLLMrpc.Notification() {
		method = "notify::key-focus",
		id = 3
	};
	var nil = GLib.Value(typeof(GLib.Object));
	nil.set_object(null);
	closed.args.add(nil);
	if (!write_note(wctx, closed, "null-object")) {
		return 1;
	}
	try {
		dout.flush();
	} catch (GLib.Error e) {
		stderr.printf("FAIL null-object-arg-gate: flush: %s\n", e.message);
		return 1;
	}

	unowned uint8[] data = mout.get_data();
	var nbytes = (size_t) mout.get_data_size();
	var bytes = new Bytes(data[0:nbytes]);
	var min = new MemoryInputStream.from_bytes(bytes);
	var din = new DataInputStream(min);
	var rctx = new OLLMrpc.Bin.Stream(din, null);

	try {
		var first = parse_one(rctx);
		if (first.args.size != 1 || !first.args.get(0).holds(typeof(bool))) {
			stderr.printf("FAIL null-object-arg-gate: open args size=%d\n", first.args.size);
			return 1;
		}
	} catch (GLib.Error e) {
		stderr.printf("FAIL null-object-arg-gate: open notification: %s\n", e.message);
		return 1;
	}

	try {
		var lease = parse_one(rctx);
		if (lease.args.size != 1
				|| !lease.args.get(0).holds(typeof(uint64))
				|| lease.args.get(0).get_uint64() != 0) {
			stderr.printf(
				"FAIL null-object-arg-gate: explicit lease 0 came back type=%s\n",
				lease.args.size > 0 ? lease.args.get(0).type().name() : "(none)");
			return 1;
		}
	} catch (GLib.Error e) {
		stderr.printf("FAIL null-object-arg-gate: explicit lease 0: %s\n", e.message);
		return 1;
	}

	try {
		var second = parse_one(rctx);
		if (second.args.size != 1
				|| !second.args.get(0).holds(typeof(uint64))
				|| second.args.get(0).get_uint64() != 0) {
			stderr.printf(
				"FAIL null-object-arg-gate: null object came back type=%s\n",
				second.args.size > 0 ? second.args.get(0).type().name() : "(none)");
			return 1;
		}
	} catch (GLib.Error e) {
		stderr.printf("FAIL null-object-arg-gate: null object: %s\n", e.message);
		return 1;
	}
	stdout.printf("PASS null-object-arg-gate\n");
	return 0;
}
