/**
 * Smoke — St.Adjustment Animatable + Interval mint (D1.7/D1.8 corridor).
 *
 *   GI_META_SMOKE=adjustment-animatable-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'adjustment-animatable-smoke';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

function main() {
	const globalObj = Shell.Global.get();
	if (globalObj == null) {
		throw new Error('adjustment-animatable-smoke: Global is null');
	}

	const adj = new St.Adjustment({
		value: 0,
		lower: 0,
		upper: 2,
		step_increment: 1,
		page_increment: 1,
		page_size: 1,
	});

	const isAnim = adj instanceof Clutter.Animatable;
	smokeLog(`instanceof Animatable=${isAnim}`);
	if (!isAnim) {
		smokeLog('FAIL: St.Adjustment is not Clutter.Animatable');
		smokeLog('done');
		return;
	}

	let pspec;
	try {
		pspec = adj.find_property('value');
	} catch (e) {
		smokeLog(`FAIL: find_property threw ${e}`);
		smokeLog('done');
		return;
	}
	if (pspec == null) {
		smokeLog('FAIL: find_property(value) returned null');
		smokeLog('done');
		return;
	}
	smokeLog(`find_property value ok type=${pspec.value_type}`);

	let interval;
	try {
		interval = new Clutter.Interval({ value_type: pspec.value_type });
	} catch (e) {
		smokeLog(`FAIL: Interval construct threw ${e}`);
		smokeLog('done');
		return;
	}
	if (interval == null) {
		smokeLog('FAIL: Interval construct returned null');
		smokeLog('done');
		return;
	}
	const got = interval.get_value_type();
	smokeLog(`Interval value_type=${got}`);
	if (got !== pspec.value_type) {
		smokeLog('FAIL: Interval value_type mismatch');
		smokeLog('done');
		return;
	}

	smokeLog('PASS');
	smokeLog('done');
}

main();
