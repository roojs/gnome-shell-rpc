/**
 * Smoke — St.Adjustment must be Clutter.Animatable (find_property / ease).
 *
 *   GI_META_SMOKE=adjustment-animatable-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Gates Animatable only. PropertyTransition / Interval / set_to stay
 * out until GValue IN + Interval construct have an isolated smoke
 * outside this tree (see bug §2).
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
	smokeLog('PASS');
	smokeLog('done');
}

main();
