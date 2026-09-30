/**
 * FAIL smoke — GJS Actor.vfunc_allocate mutates box + set_allocation;
 * does compositor geom stick? (BoxPointer._reposition path, no shell chrome.)
 *
 *   GI_META_SMOKE=actor-allocate-box-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Stock: Class->allocate mutates the ActorBox* and must call set_allocation.
 * BoxPointer._reposition only set_origin; then set_allocation(box).
 *
 * Pin if FAIL (hits>=1, still near 0,0): Helper measure_allocate calls
 * set_allocation with the *pre-hook* box after reply {@code b=false},
 * overwriting the GJS set_allocation. Do not "fix" in this smoke.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'actor-allocate-box-smoke';
const WANT_X = 200;
const WANT_Y = 80;
const WANT_W = 100;
const WANT_H = 50;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null) {
		throw new Error('actor-allocate-box-smoke: stage is null');
	}

	let hits = 0;
	let lastIn = '';
	let lastOut = '';

	const RepositionActor = GObject.registerClass(
	class RepositionActor extends St.Widget {
		vfunc_allocate(box) {
			hits++;
			lastIn = `${box.x1},${box.y1} ${box.get_width()}x${box.get_height()}`;
			const w = box.get_width();
			const h = box.get_height();
			box.init_rect(WANT_X, WANT_Y, w, h);
			lastOut = `${box.x1},${box.y1} ${box.get_width()}x${box.get_height()}`;
			smokeLog(`vfunc in=${lastIn} out=${lastOut}`);
			/* Stock BoxPointer: set_allocation after mutating origin. */
			this.set_allocation(box);
		}
	});

	const actor = new RepositionActor({
		name: 'actor-allocate-box-smoke',
		reactive: true,
	});
	actor.set_size(WANT_W, WANT_H);
	stage.add_child(actor);
	actor.show();

	const loop = new GLib.MainLoop(null, false);
	let tries = 0;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
		tries++;
		if (tries === 3) {
			const box = new Clutter.ActorBox();
			box.init_rect(0, 0, WANT_W, WANT_H);
			actor.allocate(box);
			smokeLog(`forced allocate hits=${hits}`);
		}

		const x = actor.get_x();
		const y = actor.get_y();
		const w = actor.get_width();
		const h = actor.get_height();
		smokeLog(`poll${tries} hits=${hits} geom=${x},${y} ${w}x${h}`);

		if (hits < 1 && tries < 25) {
			return GLib.SOURCE_CONTINUE;
		}
		if (hits < 1) {
			smokeLog('FAIL vfunc never ran');
			smokeLog('done');
			loop.quit();
			return GLib.SOURCE_REMOVE;
		}

		/* Allow one more layout after forced allocate. */
		if (tries < 8) {
			return GLib.SOURCE_CONTINUE;
		}

		const ax = actor.get_x();
		const ay = actor.get_y();
		if (Math.abs(ax - WANT_X) > 1 || Math.abs(ay - WANT_Y) > 1) {
			smokeLog(`FAIL geom not applied hits=${hits} geom=${ax},${ay} `
				+ `(want ${WANT_X},${WANT_Y}) in=${lastIn} out=${lastOut}`);
			smokeLog('done');
			loop.quit();
			return GLib.SOURCE_REMOVE;
		}
		smokeLog('PASS');
		smokeLog('done');
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
