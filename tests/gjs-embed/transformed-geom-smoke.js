/**
 * FAIL/observe smoke — when does get_transformed_* return NaN?
 *
 *   GI_META_SMOKE=transformed-geom-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Chrome probe sees messageTray / systemBackground @ NaN,NaN via
 * get_transformed_position/size (RPC). Pin whether that is “never
 * allocated” vs “allocated but transform NaN” on a Helper.Actor peer.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'transformed-geom-smoke';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * @param {Clutter.Actor} actor
 * @param {string} label
 */
function dump(actor, label) {
	const x = actor.get_x();
	const y = actor.get_y();
	const w = actor.get_width();
	const h = actor.get_height();
	let tx = NaN, ty = NaN, tw = NaN, th = NaN;
	try {
		[tx, ty] = actor.get_transformed_position();
		[tw, th] = actor.get_transformed_size();
	} catch (e) {
		smokeLog(label + ' transformed threw ' + e);
	}
	let box = 'n/a';
	try {
		const b = actor.get_allocation_box();
		box = `${b.get_x()},${b.get_y()} ${b.get_width()}x${b.get_height()}`;
	} catch (e) {
		box = `err:${e}`;
	}
	smokeLog(
		label
		+ ` mapped=${actor.is_mapped()} alloc=${actor.has_allocation?.() ?? '?'}`
		+ ` xywh=${x},${y} ${w}x${h}`
		+ ` box=${box}`
		+ ` xf=${tx},${ty} ${tw}x${th}`
		+ ` nan=${Number.isNaN(tx) || Number.isNaN(ty) || Number.isNaN(tw) || Number.isNaN(th)}`
	);
	return { tx, ty, tw, th, x, y, w, h };
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null)
		throw new Error('transformed-geom-smoke: stage is null');

	const orphan = new St.Widget({ name: 'transformed-geom-orphan' });
	orphan.set_size(50, 50);
	dump(orphan, 'O orphan (not on stage)');

	const actor = new St.Widget({
		name: 'transformed-geom-smoke-actor',
		reactive: true,
	});
	actor.set_size(80, 40);
	stage.add_child(actor);
	actor.show();

	dump(actor, 'A after add (no allocate)');

	const box = new Clutter.ActorBox();
	box.init_rect(10, 20, 80, 40);
	actor.allocate(box);
	dump(actor, 'B after allocate');

	actor.queue_relayout();
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
		const c = dump(actor, 'C after queue_relayout+200ms');
		try {
			if (Number.isNaN(c.tx) || Number.isNaN(c.ty))
				smokeLog('FAIL transformed-NaN after allocate');
			else if (c.tx !== c.x || c.ty !== c.y)
				smokeLog(`WARN xf!=xy xf=${c.tx},${c.ty} xy=${c.x},${c.y}`);
			else
				smokeLog('PASS finite transformed matches xy');
			smokeLog('done');
		} catch (e) {
			smokeLog('FAIL ' + e);
			smokeLog('done');
		}
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
