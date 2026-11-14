/**
 * Gate: ''LayoutHooks.measure_event'' packs ''tidduu'' without
 * ''event.get_state()'' and ''Actor.relay_event'' /
 * ''Actor.relay_captured_event'' construct ''Event.from_local'' with
 * ''state = 0''.
 *
 * ''desktop-cube'' ''DragGesture._handleEvent'' checks
 * ''(event.get_state() & BUTTON1_MASK) == 0'' on ''MOTION'' and cancels
 * ''State.PENDING'' / ''State.ACTIVE'' when ''state'' is zero.
 *
 * {{{
 * meson compile -C build captured-event-motion-state-gate
 * timeout 5 ./build/tests/call-sync-repro/captured-event-motion-state-gate current
 * timeout 5 ./build/tests/call-sync-repro/captured-event-motion-state-gate fixed
 * }}}
 */

int main(string[] args)
{
	var mode = "current";
	if (args.length >= 2) {
		mode = args[1];
	}
	if (mode != "current" && mode != "fixed") {
		GLib.stderr.printf("FAIL captured-event-motion-state-gate: mode %s\n",
			mode);
		return 2;
	}

	var button1_mask = (uint) (1 << 8);
	var server_state = button1_mask;

	/* LayoutHooks.measure_event -> Actor.relay_captured_event pack */
	var packed = OLLMrpc.args("tidduu",
		(uint64) 1,
		6,
		760.0,
		400.0,
		(uint) 0,
		(uint) 0);
	packed.add(OLLMrpc.val("u", 0u));
	packed.add(OLLMrpc.val("i", 0));
	packed.add(OLLMrpc.val("u", 12345u));
	if (mode == "fixed") {
		packed.add(OLLMrpc.val("u", server_state));
	}

	var client_state = 0u;
	if (packed.size > 9) {
		client_state = packed.get(9).get_uint();
	}

	if ((client_state & button1_mask) == 0) {
		GLib.stderr.printf(
			"FAIL captured-event-motion-state-gate %s: state=0x%x\n",
			mode, client_state);
		return 1;
	}
	GLib.stderr.printf(
		"PASS captured-event-motion-state-gate %s: state=0x%x\n",
		mode, client_state);
	return 0;
}
