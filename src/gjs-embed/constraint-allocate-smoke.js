/**
 * FAIL smoke — GJS Constraint vfunc never runs on Helper.Actor allocate.
 *
 *   GI_META_SMOKE=constraint-allocate-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Pin (do not "fix" here): mapped + has_constraints, but
 * vfunc_update_allocation hits stay 0 through stage layout and a forced
 * allocate. Next prove: whether Clutter-Actor.allocate GI hits Class->allocate
 * (skips stock constraint pass) vs public clutter_actor_allocate.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'constraint-allocate-smoke';

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
		throw new Error('constraint-allocate-smoke: stage is null');
	}

	let hits = 0;
	const FillConstraint = GObject.registerClass(
	class FillConstraint extends Clutter.Constraint {
		vfunc_update_allocation(_actor, actorBox) {
			hits++;
			actorBox.init_rect(10, 20, 800, 600);
			smokeLog('vfunc_update_allocation hit');
		}
	});

	const actor = new St.Widget({
		name: 'constraint-smoke-actor',
		reactive: true,
	});
	actor.set_size(50, 50);
	const constraint = new FillConstraint();
	smokeLog('client constraint.enabled=' + constraint.enabled);
	actor.add_constraint(constraint);
	stage.add_child(actor);
	actor.show();
	actor.queue_relayout();

	const loop = new GLib.MainLoop(null, false);
	let tries = 0;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
		tries++;
		const mapped = actor.is_mapped();
		const has = actor.has_constraints();
		smokeLog('poll' + tries
			+ ' mapped=' + mapped
			+ ' has_constraints=' + has
			+ ' hits=' + hits
			+ ' geom=' + actor.get_width() + 'x' + actor.get_height());

		if (mapped && tries === 5) {
			const box = new Clutter.ActorBox();
			box.init_rect(0, 0, 50, 50);
			actor.allocate(box);
			smokeLog('forced allocate hits=' + hits);
		}

		if (hits < 1 && tries < 20) {
			return GLib.SOURCE_CONTINUE;
		}
		if (hits < 1) {
			smokeLog('FAIL vfunc never ran (mapped=' + mapped
				+ ' has_constraints=' + has + ')');
			smokeLog('done');
			loop.quit();
			return GLib.SOURCE_REMOVE;
		}
		const w = actor.get_width();
		const h = actor.get_height();
		/* FillConstraint init_rect(10, 20, 800, 600) — size must stick. */
		if (w < 799 || h < 599) {
			smokeLog('FAIL vfunc ran but geom not applied hits=' + hits
				+ ' geom=' + w + 'x' + h);
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
