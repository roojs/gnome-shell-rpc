/**
 * Second picker launch leaves the shell dead —
 * docs/bugs/2026-10-07-picker-click-no-clicked.md
 *
 * Boots product main.start, opens the app grid, pointer-clicks two stopped
 * app icons (each launch must take), opens the grid again, and pointer-clicks
 * a third icon. The third click is the bar: a dead shell delivers no
 * button-press and no clicked, and the overview stays up.
 *
 * Pass: `picker-second-launch: ok`
 * Fail: `picker-second-launch: miss <reason>`
 *
 *   GI_META_SMOKE=picker-second-launch ./scripts/agent-nested-smoke-prove.sh
 *
 * No production code changes from this file.
 */

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'picker-second-launch';
const LAUNCH_WAIT_MS = 8000;
const GRID_WAIT_MS = 8000;

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
	global.context.terminate();
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
 * @param {string} appId
 * @param {number} baselineWindows
 * @param {number} baselineNormal
 * @param {Meta.Display} display
 * @returns {boolean}
 */
function launchTook(appId, baselineWindows, baselineNormal, display) {
	const app = Shell.AppSystem.get_default().lookup_app(appId);
	if (app != null && (app.state === Shell.AppState.RUNNING || app.get_n_windows() > baselineWindows))
		return true;
	return countNormalWindows(display) > baselineNormal;
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
		if (a.app?.get_id != null)
			return a;
		a = a.get_parent?.() ?? null;
	}
	return null;
}

/**
 * Allocation reads come back uninitialized. Pick is what a real click uses.
 *
 * @param {Clutter.Actor} stage
 * @returns {object[]}
 */
function findPickIcons(stage) {
	const hits = [];
	const seen = new Set();
	const samples = [];
	for (let y = 120; y < stage.height - 60; y += 80) {
		for (let x = 70; x < stage.width - 40; x += 100) {
			let actor = null;
			try {
				actor = stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, x, y);
			} catch (e) {
				continue;
			}
			if (samples.length < 4)
				samples.push(`${x},${y} ${actorChain(actor)}`);
			const icon = iconAt(actor);
			if (icon == null)
				continue;
			const id = icon.app.get_id();
			if (seen.has(id))
				continue;
			seen.add(id);
			icon._smokeX = x;
			icon._smokeY = y;
			hits.push(icon);
		}
	}
	smokeLog('pick-samples ' + samples.join(' | '));
	smokeLog('pick-icons=' + hits.length);
	return hits;
}

/**
 * Prefer small apps, then any other stopped icon.
 *
 * @param {object[]} icons
 * @returns {object[]}
 */
function preferStopped(icons) {
	const want = [
		'org.gnome.gedit',
		'org.gnome.TextEditor',
		'org.gnome.Calculator',
		'yelp',
	];
	const stopped = icons.filter(icon => icon.app.state === Shell.AppState.STOPPED);
	const picked = [];
	for (const id of want) {
		const hit = stopped.find(icon => icon.app.get_id().includes(id));
		if (hit != null && !picked.includes(hit))
			picked.push(hit);
	}
	for (const icon of stopped) {
		if (!picked.includes(icon))
			picked.push(icon);
	}
	return picked;
}

/**
 * IconGrid.vfunc_allocate is what calls adaptToSize. The controls layout
 * allocates the app display straight into IconGridLayout, which throws
 * while the page size is still 0. Set the page size here so the next
 * allocate can place icons and ClickAction can see the release as inside.
 *
 * @param {object} appDisplay
 */
function primeGrid(appDisplay) {
	const grid = appDisplay._grid;
	const layout = grid?.layout_manager;
	if (layout?.adaptToSize == null) {
		smokeLog('prime no-layout');
		return;
	}
	let w = 1100;
	let h = 500;
	try {
		const box = appDisplay.get_allocation_box();
		const bw = box.get_width();
		const bh = box.get_height();
		if (Number.isFinite(bw) && bw > 50)
			w = bw;
		if (Number.isFinite(bh) && bh > 50)
			h = bh;
	} catch (e) {
		smokeLog('prime box ' + formatError(e));
	}
	try {
		layout.adaptToSize(w, h);
		grid.queue_relayout();
	} catch (e) {
		smokeLog('prime threw ' + formatError(e));
		return;
	}
	smokeLog('prime page=' + layout._pageWidth + 'x' + layout._pageHeight);
}

/**
 * @param {object} main
 * @param {object} appDisplay
 * @param {Clutter.Actor} stage
 * @returns {Promise<object[]>}
 */
async function waitGrid(main, appDisplay, stage) {
	// Opening the grid while _redisplay is still adding icons re-enters
	// IconGridLayout.allocate before adaptToSize and throws in a loop.
	// Wait until the item count stops growing, then open the grid.
	let lastCount = -1;
	let stable = 0;
	const fillDeadline = GLib.get_monotonic_time() + 12 * GLib.TIME_SPAN_SECOND;
	while (stable < 3 && GLib.get_monotonic_time() < fillDeadline) {
		const n = appDisplay._orderedItems?.length ?? 0;
		if (n > 0 && n === lastCount)
			stable++;
		else
			stable = 0;
		lastCount = n;
		await delay(300);
	}
	smokeLog('grid-fill items=' + lastCount);
	// showApps() returns immediately once the overview is already shown.
	// The picker is ControlsState.APP_GRID (2).
	if (!main.overview.visible)
		main.overview.showApps();
	const showApps = main.overview.dash?.showAppsButton;
	if (showApps != null && !showApps.checked)
		showApps.checked = true;
	const adj = main.overview._overview?.controls?._stateAdjustment;
	if (adj != null && adj.value < 1.9) {
		adj.ease(2, {
			duration: 0,
			mode: Clutter.AnimationMode.EASE_OUT_QUAD,
		});
	}
	smokeLog('grid-state value=' + (adj?.value ?? 'none')
		+ ' checked=' + (showApps?.checked ?? 'none')
		+ ' displayMapped=' + appDisplay.mapped);
	primeGrid(appDisplay);
	const deadline = GLib.get_monotonic_time() + GRID_WAIT_MS * 1000;
	let icons = [];
	while (GLib.get_monotonic_time() < deadline) {
		await delay(400);
		icons = findPickIcons(stage);
		if (main.overview.visible && icons.length >= 2)
			return icons;
	}
	return icons;
}

/**
 * @param {Clutter.Actor} stage
 * @param {object} globalObj
 * @param {object} icon
 * @returns {Promise<{press: number, release: number, clicked: boolean, picked: string}>}
 */
async function pointerClickIcon(stage, globalObj, icon) {
	const cx = icon._smokeX;
	const cy = icon._smokeY;
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
	smokeLog('click-begin id=' + icon.app.get_id() + ' @' + cx + ',' + cy);
	let picked = '';
	try {
		const actor = stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, cx, cy);
		picked = actor != null ? (actor.name || actor.toString()) : 'null';
	} catch (e) {
		picked = 'pick-threw ' + formatError(e);
	}
	try {
		globalObj.pointer_click(cx, cy);
	} catch (e) {
		stage.disconnect(hid);
		icon.disconnect(cid);
		throw e;
	}
	await delay(700);
	stage.disconnect(hid);
	icon.disconnect(cid);
	let boxLine = 'n/a';
	try {
		const box = icon.get_allocation_box();
		boxLine = box.get_x() + ',' + box.get_y() + ' ' + box.get_width() + 'x' + box.get_height();
	} catch (e) {
		boxLine = formatError(e);
	}
	smokeLog(`click id=${icon.app.get_id()} @${cx.toFixed(0)},${cy.toFixed(0)} press=${press} release=${release} clicked=${clicked} pick=${picked} box=${boxLine}`);
	return {press, release, clicked, picked};
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

	const readyDeadline = GLib.get_monotonic_time() + 15 * GLib.TIME_SPAN_SECOND;
	while (!main.overview.visible && GLib.get_monotonic_time() < readyDeadline)
		await delay(200);
	smokeLog('overview.visible=' + main.overview.visible);

	const appDisplay = main.overview._overview?.controls?.appDisplay;
	if (appDisplay == null) {
		finishMiss('no appDisplay');
		return;
	}

	let icons = await waitGrid(main, appDisplay, stage);
	const stopped = preferStopped(icons);
	smokeLog('grid=' + icons.length + ' stopped=' + stopped.length
		+ ' ids=' + stopped.slice(0, 4).map(icon => icon.app.get_id()).join(','));
	if (stopped.length < 2) {
		finishMiss('need two stopped icons');
		return;
	}

	const first = stopped[0];
	const second = stopped[1];
	const third = stopped[2] ?? first;

	const baseNormal = countNormalWindows(display);
	const base1 = first.app.get_n_windows();
	await pointerClickIcon(stage, globalObj, first);
	const launch1Deadline = GLib.get_monotonic_time() + LAUNCH_WAIT_MS * 1000;
	let launch1 = false;
	while (GLib.get_monotonic_time() < launch1Deadline) {
		launch1 = launchTook(first.app.get_id(), base1, baseNormal, display);
		if (launch1)
			break;
		await delay(200);
	}
	smokeLog('launch1 id=' + first.app.get_id()
		+ ' state=' + first.app.state
		+ ' windows=' + countNormalWindows(display)
		+ ' took=' + launch1);
	if (!launch1) {
		finishMiss('launch1');
		return;
	}

	const hideDeadline = GLib.get_monotonic_time() + 4000 * 1000;
	while (main.overview.visible && GLib.get_monotonic_time() < hideDeadline)
		await delay(200);

	icons = await waitGrid(main, appDisplay, stage);
	const secondIcon = icons.find(icon => icon.app.get_id() === second.app.get_id()) ?? second;
	const baseNormal2 = countNormalWindows(display);
	const base2 = secondIcon.app.get_n_windows();
	await pointerClickIcon(stage, globalObj, secondIcon);
	const launch2Deadline = GLib.get_monotonic_time() + LAUNCH_WAIT_MS * 1000;
	let launch2 = false;
	while (GLib.get_monotonic_time() < launch2Deadline) {
		launch2 = launchTook(secondIcon.app.get_id(), base2, baseNormal2, display);
		if (launch2)
			break;
		await delay(200);
	}
	smokeLog('launch2 id=' + secondIcon.app.get_id()
		+ ' state=' + secondIcon.app.state
		+ ' windows=' + countNormalWindows(display)
		+ ' took=' + launch2);
	if (!launch2) {
		finishMiss('launch2');
		return;
	}

	const hide2Deadline = GLib.get_monotonic_time() + 4000 * 1000;
	while (main.overview.visible && GLib.get_monotonic_time() < hide2Deadline)
		await delay(200);

	icons = await waitGrid(main, appDisplay, stage);
	smokeLog('grid-after2 visible=' + main.overview.visible + ' icons=' + icons.length);
	if (!main.overview.visible || icons.length < 1) {
		finishMiss('grid-after2');
		return;
	}

	const thirdIcon = icons.find(icon => icon.app.get_id() === third.app.get_id()) ?? icons[0];
	const beforeVisible = main.overview.visible;
	const click3 = await pointerClickIcon(stage, globalObj, thirdIcon);
	await delay(1500);
	const stillUp = main.overview.visible;
	smokeLog('after3 visible=' + stillUp + ' was=' + beforeVisible
		+ ' press=' + click3.press + ' clicked=' + click3.clicked);
	if (click3.press === 0 && !click3.clicked && stillUp) {
		finishMiss('dead-after-second');
		return;
	}
	if (!click3.clicked && stillUp) {
		finishMiss('no-clicked-after-second');
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
			smokeLog('FAIL start ' + formatError(e));
			const error = new GLib.Error(
				Gio.IOErrorEnum, Gio.IOErrorEnum.FAILED, formatError(e));
			global.context.terminate_with_error(error);
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
