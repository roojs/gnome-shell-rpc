/**
 * Pin — PopupMenuManager close: grab + captured-event + get_event_actor.
 *
 * Stock popupMenu.js _onCapturedEvent: stage.get_event_actor(event) then
 * !actor.contains(target) → menu.close(). Clock / QS stay open when the
 * grab actor never sees captured-event or get_event_actor is unwired.
 *
 *   GI_META_SMOKE=captured-event-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'captured-event-smoke';
const GRAB_X = 40;
const GRAB_Y = 40;
const TGT_X = 220;
const TGT_Y = 40;
const W = 80;
const H = 40;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * @param {number} ms
 */
function waitMs(ms) {
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null) {
		throw new Error('captured-event-smoke: stage is null');
	}

	let sawCaptured = 0;
	let picked = null;
	let pickThrew = null;

	const Grabber = GObject.registerClass(
	class Grabber extends St.Widget {
	});

	const grabber = new Grabber({
		name: 'captured-event-smoke-grabber',
		reactive: true,
		can_focus: true,
	});
	grabber.set_position(GRAB_X, GRAB_Y);
	grabber.set_size(W, H);
	grabber.set_style('background-color: #8e44ad;');

	const target = new St.Widget({
		name: 'captured-event-smoke-target',
		reactive: true,
		can_focus: true,
	});
	target.set_position(TGT_X, TGT_Y);
	target.set_size(W, H);
	target.set_style('background-color: #16a085;');

	stage.add_child(grabber);
	stage.add_child(target);
	grabber.show();
	target.show();

	grabber.connect('captured-event', (actor, event) => {
		const t = event.type();
		let ex = '?', ey = '?';
		try {
			const coords = event.get_coords();
			if (Array.isArray(coords)) {
				ex = coords[0];
				ey = coords[1];
			}
		} catch (e) {}
		smokeLog('captured-event type=' + t + ' @ ' + ex + ',' + ey);
		if (t === Clutter.EventType.BUTTON_PRESS
				|| t === Clutter.EventType.TOUCH_BEGIN) {
			sawCaptured++;
			try {
				picked = stage.get_event_actor(event);
			} catch (e) {
				pickThrew = String(e);
			}
		}
		return Clutter.EVENT_PROPAGATE;
	});

	const grab = stage.grab(grabber);
	if (grab == null) {
		throw new Error('captured-event-smoke: stage.grab returned null');
	}
	smokeLog('grab ok');

	const cx = TGT_X + W / 2;
	const cy = TGT_Y + H / 2;
	smokeLog('pointer_click @ ' + cx + ',' + cy);
	globalObj.pointer_click(cx, cy);
	waitMs(200);

	const actorTag = (a) => {
		if (a == null)
			return 'null';
		let geom = '?';
		try {
			const [x, y] = a.get_transformed_position();
			const [w, h] = a.get_transformed_size();
			geom = `${Math.round(x)},${Math.round(y)} ${Math.round(w)}x${Math.round(h)}`;
		} catch (e) {
			geom = `err:${e}`;
		}
		return `${a.get_name() || '?'} type=${a.constructor?.name ?? a} ${geom}`
			+ ` stage=${a === stage} grabber=${a === grabber} target=${a === target}`;
	};
	try {
		const [tx, ty] = target.get_transformed_position();
		const [tw, th] = target.get_transformed_size();
		smokeLog(`target geom ${Math.round(tx)},${Math.round(ty)} ${Math.round(tw)}x${Math.round(th)} reactive=${target.reactive}`);
	} catch (e) {
		smokeLog(`target geom threw ${e}`);
	}
	try {
		const at = stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, cx, cy);
		smokeLog('get_actor_at_pos REACTIVE ' + actorTag(at));
	} catch (e) {
		smokeLog(`get_actor_at_pos threw ${e}`);
	}
	smokeLog('sawCaptured=' + sawCaptured
		+ ' picked=' + actorTag(picked)
		+ (pickThrew ? ' pickThrew=' + pickThrew : ''));

	if (sawCaptured < 1) {
		throw new Error(
			'captured-event-smoke: no captured-event on grab actor after pointer_click');
	}
	if (pickThrew) {
		throw new Error(
			'captured-event-smoke: get_event_actor threw ' + pickThrew);
	}
	if (picked == null) {
		throw new Error('captured-event-smoke: get_event_actor returned null');
	}
	/* Stock PopupMenuManager: !actor.contains(target) → close. */
	if (grabber.contains(picked)) {
		throw new Error(
			'captured-event-smoke: get_event_actor returned grabber-tree '
			+ actorTag(picked));
	}
	const at = stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, cx, cy);
	if (at !== target && !target.contains(at)) {
		throw new Error(
			'captured-event-smoke: get_actor_at_pos expected target, got '
			+ actorTag(at));
	}

	if (grab.dismiss) {
		grab.dismiss();
	}
	smokeLog('ok');
}

main();
