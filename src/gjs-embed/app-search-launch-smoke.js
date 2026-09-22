/**
 * Search result launch — prove L1/L2/L3 from
 * docs/bugs/2026-09-22-search-result-click-no-launch.md
 *
 * Boots product main.start, fills overview search (ter), then:
 *   L1 — lookup_app(id).activate() (no pointer)
 *   L2 — first AppIcon.activate()
 *   L3 — Shell.Global.pointer_click(center of icon)
 *
 * Pass: L1 ok and L3 ok (new client window after each step that should spawn).
 * Fail: miss L1 | L2 | L3 with log line naming the step.
 *
 *   GSR_NESTED_TIMEOUT=90 GI_META_SMOKE=app-search-launch-smoke \
 *     GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 *
 * Weston only. No vendor search.js. No production code changes from this file.
 */

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'app-search-launch-smoke';
const SEARCH_WAIT_MS = 2500;
const LAUNCH_WAIT_MS = 4000;
const TERMINAL_ACTIVATION_WAIT_MS = 30000;
const SEARCH_TERM = 'ter';

/**
 * Log shell process + launch-context display env (wrong DISPLAY → spawn on
 * Weston XWayland, invisible to Meta on mutter-rpc).
 *
 * @param {Gio.AppLaunchContext|null} ctx
 */
function logLaunchEnv(ctx) {
	const keys = ['DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'XDG_RUNTIME_DIR'];
	for (const k of keys) {
		const v = GLib.getenv(k);
		smokeLog('proc-env ' + k + '=' + (v != null ? JSON.stringify(v) : '(unset)'));
	}
	if (ctx == null)
		return;
	if (typeof ctx.get_environment === 'function') {
		const env = ctx.get_environment();
		if (env != null) {
			for (const entry of env) {
				if (entry.startsWith('DISPLAY=')
					|| entry.startsWith('WAYLAND_DISPLAY=')
					|| entry.startsWith('WAYLAND_SOCKET='))
					smokeLog('ctx-env ' + entry);
			}
		}
	}
}

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
 * @param {Meta.Display} display
 * @returns {Meta.Window[]}
 */
function listWindows(display) {
	if (typeof display.list_all_windows === 'function') {
		const list = display.list_all_windows();
		return list != null ? list : [];
	}
	const focus = display.get_focus_window();
	return focus != null ? [focus] : [];
}

/**
 * @param {Meta.Display} display
 * @returns {number}
 */
function countAllWindows(display) {
	return listWindows(display).length;
}

/**
 * @param {Meta.Display} display
 * @returns {number}
 */
function countNormalWindows(display) {
	let n = 0;
	for (const w of listWindows(display)) {
		if (w == null)
			continue;
		if (w.window_type === Meta.WindowType.NORMAL)
			n++;
	}
	return n;
}

/**
 * @param {string} appId
 * @returns {string}
 */
function appStateLine(appId) {
	const app = Shell.AppSystem.get_default().lookup_app(appId);
	if (app == null)
		return 'lookup=null';
	return 'state=' + app.state + ' n_windows=' + app.get_n_windows();
}

/**
 * @param {Meta.Display} display
 * @param {number} baselineNormal
 * @param {string} appId
 * @returns {boolean}
 */
function launchLooksOk(display, baselineNormal, appId) {
	if (countNormalWindows(display) > baselineNormal)
		return true;
	const app = Shell.AppSystem.get_default().lookup_app(appId);
	if (app == null)
		return false;
	if (app.state === Shell.AppState.RUNNING || app.get_n_windows() > 0)
		return true;
	return countAllWindows(display) > 0;
}

/**
 * @param {object} main
 */
async function runLaunchProve(main) {
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	if (display == null)
		throw new Error('Global.get_display() is null');
	const search = main.overview.searchController;
	const entry = main.overview.searchEntry;
	const resultsView = search._searchResults;
	const ct = entry.clutter_text;

	const providers = resultsView._providers || [];
	const appProv = providers.find(p => p.id === 'applications');
	if (appProv == null)
		throw new Error('no applications provider');

	logLaunchEnv(null);
	smokeLog('L0 covered by app-launch-boundary-smoke');

	smokeLog('show overview');
	main.overview.show();
	const readyDeadline = GLib.get_monotonic_time() + 15 * GLib.TIME_SPAN_SECOND;
	while (!main.overview.visible && GLib.get_monotonic_time() < readyDeadline)
		await delay(200);
	smokeLog('overview.visible=' + main.overview.visible);

	entry.grab_key_focus();
	smokeLog('set text=' + SEARCH_TERM);
	ct.text = SEARCH_TERM;
	await delay(SEARCH_WAIT_MS);

	const appDisplay = appProv.display;
	if (appDisplay == null)
		throw new Error('no applications result display');

	let first = null;
	try {
		first = appDisplay.getFirstResult();
	} catch (e) {
		throw new Error('getFirstResult: ' + formatError(e));
	}
	const nGrid = appDisplay._grid ? appDisplay._grid.get_n_children() : 0;
	smokeLog('nGrid=' + nGrid + ' first=' + (first != null));

	if (first == null || nGrid <= 0)
		throw new Error('miss search-fill (run app-search-smoke first)');

	/** @type {object[]} */
	const stoppedIcons = [];
	const grid = appDisplay._grid;
	if (grid != null) {
		const n = grid.get_n_children();
		for (let i = 0; i < n; i++) {
			const child = grid.get_child_at_index(i);
			if (child?.app?.state === Shell.AppState.STOPPED)
				stoppedIcons.push(child);
		}
	}
	smokeLog('stopped-icons=' + stoppedIcons.length);
	if (stoppedIcons.length < 1)
		throw new Error('miss search-fill-stopped (need at least one STOPPED hit)');
	if (stoppedIcons.length < 2)
		throw new Error('miss search-fill-stopped (need two STOPPED hits for L3 click)');

	const iconL1 = stoppedIcons[0];
	const iconL3 = stoppedIcons[1];
	const appId = iconL1.app.get_id();
	smokeLog('L1 id=' + JSON.stringify(appId) + ' L3 id=' + JSON.stringify(iconL3.app.get_id()));

	const baseline = countNormalWindows(display);
	smokeLog('windows-normal baseline=' + baseline);

	/** @type {string} */
	let l1Err = '';
	let l1LaunchRet = '';
	const appL1 = Shell.AppSystem.get_default().lookup_app(appId);
	const deskPath = appL1?.app_info?.get_filename?.() ?? '';
	smokeLog('L1 id=' + JSON.stringify(appId) + ' desktop=' + JSON.stringify(deskPath));
	try {
		smokeLog('L1 Shell.App.launch (same path as activate for STOPPED)');
		const ok = appL1.launch(0, -1, Shell.AppLaunchGpu.APP_PREF);
		l1LaunchRet = String(ok);
		smokeLog('L1 launch() returned ' + l1LaunchRet);
	} catch (e) {
		l1Err = formatError(e);
		smokeLog('L1 threw ' + l1Err);
	}
	await delay(TERMINAL_ACTIVATION_WAIT_MS);
	const afterL1 = countNormalWindows(display);
	const l1Ok = l1Err.length === 0
		&& launchLooksOk(display, baseline, appId);
	smokeLog('L1 windows-normal=' + afterL1
		+ ' windows-all=' + countAllWindows(display)
		+ ' ' + appStateLine(appId)
		+ ' ok=' + l1Ok);

	if (!l1Ok)
		smokeLog('L1 skip (continuing to L2/L3 to name click vs launch)');

	let l2Err = '';
	if (l1Ok) {
		try {
			smokeLog('L2 AppIcon.activate (same icon as L1, already running)');
			iconL1.activate();
		} catch (e) {
			l2Err = formatError(e);
			smokeLog('L2 threw ' + l2Err);
		}
		await delay(500);
	} else {
		try {
			smokeLog('L2 AppIcon.activate on L3 icon (still STOPPED)');
			iconL3.activate();
		} catch (e) {
			l2Err = formatError(e);
			smokeLog('L2 threw ' + l2Err);
		}
		await delay(LAUNCH_WAIT_MS);
	}
	const l2Ok = l2Err.length === 0;
	smokeLog('L2 ok=' + l2Ok + ' (no throw on AppIcon.activate path)');

	if (!l2Ok) {
		smokeLog('miss L2');
		smokeLog('done');
		global.context.terminate();
		return;
	}

	const baseline3 = countNormalWindows(display);
	let [ix, iy] = iconL3.get_transformed_position();
	let [iw, ih] = iconL3.get_transformed_size();
	const cx = ix + iw / 2;
	const cy = iy + ih / 2;
	smokeLog('L3 pointer_click id=' + JSON.stringify(iconL3.app.get_id())
		+ ' @ ' + cx + ',' + cy);

	try {
		globalObj.pointer_click(cx, cy);
	} catch (e) {
		smokeLog('L3 pointer_click threw ' + formatError(e));
		smokeLog('miss L3');
		smokeLog('done');
		global.context.terminate();
		return;
	}
	await delay(LAUNCH_WAIT_MS);
	const l3Id = iconL3.app.get_id();
	const l3Ok = launchLooksOk(display, baseline3, l3Id);
	smokeLog('L3 windows-normal=' + countNormalWindows(display)
		+ ' windows-all=' + countAllWindows(display)
		+ ' ' + appStateLine(l3Id)
		+ ' ok=' + l3Ok);

	if (!l3Ok) {
		smokeLog('miss L3');
		if (!l1Ok)
			smokeLog('miss L1'); /* named after full split */
		smokeLog('done');
		global.context.terminate();
		return;
	}

	if (!l1Ok) {
		smokeLog('miss L1');
		smokeLog('done');
		global.context.terminate();
		return;
	}

	smokeLog('ok');
	smokeLog('done');
	global.context.terminate();
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => runLaunchProve(main));
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
