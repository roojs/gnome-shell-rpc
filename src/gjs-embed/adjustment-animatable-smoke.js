/**
 * FAIL smoke — St.Adjustment must be Clutter.Animatable for ease().
 *
 *   GI_META_SMOKE=adjustment-animatable-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Stock: St.Adjustment implements Clutter.Animatable; environment.js
 * St.Adjustment.prototype.ease → find_property + add_transition.
 * Overview startup calls _stateAdjustment.ease — cast failure leaves
 * overview showing (grey) and blocks menu dismiss.
 *
 * Pin if FAIL: stub GType lacks Animatable while typelib (distro GIR)
 * claims it. Do not "fix" in this smoke.
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
	const stage = globalObj.get_stage();
	if (stage == null) {
		throw new Error('adjustment-animatable-smoke: stage is null');
	}

	const adj = new St.Adjustment({
		value: 0,
		lower: 0,
		upper: 2,
		step_increment: 1,
		page_increment: 1,
		page_size: 1,
		actor: stage,
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

	/* environment.js patches ease onto the prototype after ui load.
	 * Smoke may run earlier — drive the same Animatable path manually. */
	let transition;
	try {
		transition = new Clutter.PropertyTransition({
			property_name: 'value',
			interval: new Clutter.Interval({value_type: pspec.value_type}),
			duration: 50,
			remove_on_complete: true,
		});
		transition.set_to(2);
	} catch (e) {
		smokeLog(`FAIL: PropertyTransition/set_to threw ${e}`);
		smokeLog('done');
		return;
	}

	const loop = new GLib.MainLoop(null, false);
	let stopped = false;
	transition.connect('stopped', () => {
		stopped = true;
		smokeLog(`stopped value=${adj.value}`);
		loop.quit();
	});

	try {
		adj.add_transition('value', transition);
	} catch (e) {
		smokeLog(`FAIL: add_transition threw ${e}`);
		smokeLog('done');
		return;
	}

	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
		smokeLog(`poll value=${adj.value}`);
		return GLib.SOURCE_CONTINUE;
	});

	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
		if (!stopped) {
			smokeLog(`FAIL: transition did not stop within 2s value=${adj.value}`);
			loop.quit();
		}
		return GLib.SOURCE_REMOVE;
	});

	loop.run();

	if (stopped && adj.value === 2) {
		smokeLog('PASS');
	} else if (stopped) {
		smokeLog(`FAIL: stopped but value=${adj.value} want=2`);
	} else {
		smokeLog('FAIL: transition never stopped');
	}
	smokeLog('done');
}

main();
