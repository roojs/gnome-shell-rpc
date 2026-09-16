/**
 * FAIL smoke — Interval.peek_initial_value must match stock ABI
 * (returns GValue*, not void+out) and not SEGV.
 *
 *   GI_META_SMOKE=interval-peek-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.Clutter = '16';
imports.gi.versions.GObject = '2.0';

const { GObject, Shell, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'interval-peek-smoke';
function smokeLog(m) { log(SMOKE_DOMAIN + ': ' + m); }

function main() {
	Shell.Global.get().get_stage();

	const interval = new Clutter.Interval({ value_type: GObject.TYPE_DOUBLE });
	const initial = new GObject.Value();
	initial.init(GObject.TYPE_DOUBLE);
	initial.set_double(1.5);
	interval.set_initial(initial);

	let peeked;
	try {
		peeked = interval.peek_initial_value();
	} catch (e) {
		smokeLog('FAIL peek threw ' + e);
		return;
	}
	if (peeked == null) {
		smokeLog('FAIL peek returned null');
		return;
	}
	const got = peeked.get_double();
	if (got !== 1.5) {
		smokeLog('FAIL peek=' + got + ' want 1.5');
		return;
	}
	smokeLog('PASS peek=' + got);
	smokeLog('done');
}

main();
