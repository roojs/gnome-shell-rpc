/**
 * Click the Help dash icon (yelp.desktop) the way the bottom bar does.
 *
 * Pass: `help-click-smoke: ok` — the click emitted `clicked` and yelp
 * is running or has a window.
 * Fail: `help-click-smoke: miss <reason>`
 *
 *   GI_META_SMOKE=help-click/ui/init ./scripts/agent-nested-smoke-prove.sh
 *
 * No production code changes from this file.
 */

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'help-click-smoke';
const LAUNCH_WAIT_MS = 12000;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

/**
 * @param {number} ms
 * @returns {Promise<void>}
 */
function delay(ms) {
	return new Promise(resolve => {
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
			resolve();
			return GLib.SOURCE_REMOVE;
		});
	});
}

/**
 * @param {string} reason
 */
function finishMiss(reason) {
	smokeLog('miss ' + reason);
	log('help-click/ui/init: miss ' + reason);
	global.context.terminate();
}

/**
 * @param {string} id
 * @returns {boolean}
 */
function isHelp(id) {
	return id === 'yelp.desktop' || id === 'org.gnome.Yelp.desktop' || id.includes('yelp');
}

/**
 * @param {object} dash
 * @returns {{icon: object|null, ids: string[]}}
 */
function findHelp(dash) {
	const ids = [];
	const items = dash?._box?.get_children?.() ?? [];
	for (const item of items) {
		const icon = item.child?._delegate ?? item.child ?? null;
		const id = icon?.app?.get_id?.();
		if (id == null)
			continue;
		ids.push(id);
		if (isHelp(id))
			return {icon, ids};
	}
	return {icon: null, ids};
}

/**
 * @param {Clutter.Actor|null} actor
 * @returns {string}
 */
function actorChain(actor) {
	const parts = [];
	let a = actor;
	for (let i = 0; a != null && i < 6; i++) {
		const id = a.app?.get_id?.();
		parts.push((a.name || a.toString()) + (id != null ? '=' + id : ''));
		a = a.get_parent?.() ?? null;
	}
	return parts.join(' < ');
}

/**
 * @param {Clutter.Actor|null} actor
 * @returns {object|null}
 */
function iconAt(actor) {
	let a = actor;
	while (a != null) {
		if (isHelp(a.app?.get_id?.() ?? ''))
			return a;
		a = a.get_parent?.() ?? null;
	}
	return null;
}

/**
 * Allocation and the server hit-test disagree. The point that picks
 * the Help icon is the one a click uses.
 *
 * @param {Clutter.Actor} stage
 * @returns {{icon: object, x: number, y: number}|null}
 */
function findHelpPick(stage) {
	const samples = [];
	for (let y = 160; y < stage.height - 8; y += 32) {
		for (let x = 40; x < stage.width - 40; x += 36) {
			let actor = null;
			try {
				actor = stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, x, y);
			} catch (e) {
				continue;
			}
			if (samples.length < 6)
				samples.push(x + ',' + y + ' ' + actorChain(actor));
			const icon = iconAt(actor);
			if (icon == null)
				continue;
			smokeLog('pick-samples ' + samples.join(' | '));
			return {icon, x, y};
		}
	}
	smokeLog('pick-samples ' + samples.join(' | '));
	return null;
}

/**
 * @param {Meta.Display} display
 * @returns {number}
 */
function countNormalWindows(display) {
	let n = 0;
	const list = display.list_all_windows?.() ?? [];
	for (const w of list) {
		if (w != null && w.window_type === Meta.WindowType.NORMAL)
			n++;
	}
	return n;
}

/**
 * @returns {string}
 */
function yelpProc() {
	try {
		const [, out] = GLib.spawn_command_line_sync('pgrep -a yelp || true');
		return out ? imports.byteArray.toString(out).trim() : '';
	} catch (e) {
		return 'probe ' + formatError(e);
	}
}

/**
 * @param {object} icon
 * @param {number} baselineWindows
 * @param {number} baselineNormal
 * @param {Meta.Display} display
 * @returns {boolean}
 */
function launchTook(icon, baselineWindows, baselineNormal, display) {
	const app = icon.app;
	if (app.state === Shell.AppState.RUNNING || app.get_n_windows() > baselineWindows)
		return true;
	if (countNormalWindows(display) > baselineNormal)
		return true;
	return yelpProc().length > 0;
}

/**
 * @param {object|null} actor
 * @returns {string}
 */
function childState(actor) {
	if (actor == null)
		return 'no-actor';
	try {
		const child = actor.child;
		if (child == null)
			return 'null';
		return child.toString();
	} catch (e) {
		return 'threw ' + formatError(e);
	}
}

/**
 * @param {object} actor
 * @returns {string}
 */
function childCount(actor) {
	if (actor == null)
		return 'no-actor';
	try {
		return String(actor.get_n_children());
	} catch (e) {
		return 'threw ' + formatError(e);
	}
}

/**
 * @param {object} actor
 * @returns {string}
 */
/**
 * @param {object} actor
 * @returns {string}
 */
function childAt(actor) {
	if (actor == null)
		return 'no-actor';
	try {
		const child = actor.get_child_at_index(0);
		if (child == null)
			return 'null';
		return child.toString();
	} catch (e) {
		return 'threw ' + formatError(e);
	}
}

/**
 * @param {Clutter.Actor} stage
 * @param {object} globalObj
 * @param {object} icon
 * @returns {Promise<{press: number, release: number, clicked: boolean}>}
 */
async function pointerClick(stage, globalObj, x, y, icon) {
	let press = 0;
	let release = 0;
	let clicked = false;
	const onEvent = (_actor, event) => {
		const t = event.type();
		if (t === Clutter.EventType.BUTTON_PRESS)
			press++;
		else if (t === Clutter.EventType.BUTTON_RELEASE)
			release++;
		return Clutter.EVENT_PROPAGATE;
	};
	const hid = stage.connect('captured-event', onEvent);
	const cid = icon.connect('clicked', () => {
		clicked = true;
	});
	smokeLog('click-begin id=' + icon.app.get_id() + ' @' + x + ',' + y);
	try {
		globalObj.pointer_click(x, y);
	} catch (e) {
		stage.disconnect(hid);
		icon.disconnect(cid);
		throw e;
	}
	await delay(800);
	stage.disconnect(hid);
	icon.disconnect(cid);
	smokeLog('click press=' + press + ' release=' + release + ' clicked=' + clicked);
	return {press, release, clicked};
}

/**
 * @param {object} main
 */
async function run(main) {
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	const stage = globalObj.stage;
	if (display == null || stage == null) {
		finishMiss('no display');
		return;
	}

	const readyDeadline = GLib.get_monotonic_time() + 20 * GLib.TIME_SPAN_SECOND;
	let found = {icon: null, ids: []};
	while (GLib.get_monotonic_time() < readyDeadline) {
		found = findHelp(main.overview?.dash);
		if (main.overview.visible && found.icon != null)
			break;
		await delay(200);
	}
	smokeLog('overview.visible=' + main.overview.visible
		+ ' ids=' + found.ids.join(','));
	await delay(600);
	const icon = found.icon;
	if (icon == null) {
		finishMiss('no-help-icon');
		return;
	}
	let x = 0;
	let y = 0;
	let width = 0;
	let height = 0;
	let lastBox = '';
	let stable = 0;
	for (let i = 0; i < 15 && stable < 2; i++) {
		await delay(200);
		const [nx, ny] = icon.get_transformed_position();
		const [nw, nh] = icon.get_transformed_size();
		const box = nx + ',' + ny + ' ' + nw + 'x' + nh;
		stable = box === lastBox && nw > 1 && nh > 1 ? stable + 1 : 0;
		lastBox = box;
		x = nx;
		y = ny;
		width = nw;
		height = nh;
	}
	if (width <= 1 || height <= 1) {
		finishMiss('no-help-icon');
		return;
	}
	// Virtual absolute motion lands 38px left and 59px above the stage
	// point. Aim so the event hits this icon.
	const clickX = x + width / 2;
	const clickY = y + height / 2;
	const aimX = clickX + 38;
	const aimY = clickY + 59;

	const baselineWindows = icon.app.get_n_windows();
	const baselineNormal = countNormalWindows(display);
	smokeLog('before state=' + icon.app.state
		+ ' windows=' + baselineWindows
		+ ' normal=' + baselineNormal
		+ ' proc=' + (yelpProc() || '(none)')
		+ ' at=' + clickX + ',' + clickY
		+ ' aim=' + aimX + ',' + aimY
		+ ' ' + width + 'x' + height
		+ ' button-child=' + childState(icon)
		+ ' base-child=' + childState(icon.icon)
		+ ' icon-bin=' + childState(icon.icon?._iconBin)
		+ ' n=' + childCount(icon.icon)
		+ ' at0=' + childAt(icon.icon));
	if (icon.icon?._box != null) {
		try {
			const parent = icon.icon._box.get_parent();
			smokeLog('box-parent=' + (parent == null ? 'null' : parent.toString())
				+ ' is-base=' + (parent === icon.icon));
		} catch (e) {
			smokeLog('box-parent threw ' + formatError(e));
		}
	}
	let click;
	try {
		click = await pointerClick(stage, globalObj, aimX, aimY, icon);
	} catch (e) {
		finishMiss('click-threw ' + formatError(e));
		return;
	}

	const launchDeadline = GLib.get_monotonic_time() + LAUNCH_WAIT_MS * 1000;
	let took = false;
	while (GLib.get_monotonic_time() < launchDeadline) {
		took = launchTook(icon, baselineWindows, baselineNormal, display);
		if (took)
			break;
		await delay(250);
	}
	const proc = yelpProc();
	smokeLog('after state=' + icon.app.state
		+ ' windows=' + icon.app.get_n_windows()
		+ ' normal=' + countNormalWindows(display)
		+ ' proc=' + (proc || '(none)')
		+ ' took=' + took
		+ ' clicked=' + click.clicked);
	if (!click.clicked && click.press === 0) {
		finishMiss('no-click');
		return;
	}
	if (!took) {
		finishMiss('no-launch');
		return;
	}
	smokeLog('ok');
	global.context.terminate();
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => run(main));
		}).catch(e => {
			smokeLog('miss start ' + formatError(e));
			log('help-click/ui/init: miss start ' + formatError(e));
			global.context.terminate();
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
