/**
 * Enable Desktop Icons and see whether one desktop window is
 * hidden from the dash. Two "Desktop Icons" windows is the
 * doubled desktop. A running app for that window is the gjs
 * footer entry.
 *
 * Pass: `ding-icons: ok`
 * Fail: `ding-icons: miss …`
 *
 *   GSR_NESTED_TIMEOUT=50 GI_META_SMOKE=ding-icons/ui/init \
 *     ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { GLib, Shell } = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';
import {ExtensionState} from 'resource:///org/gnome/shell/misc/extensionUtils.js';

const SMOKE = 'ding-icons/ui/init';
const DING = 'ding@rastersoft.com';

function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function delay(ms) {
	return new Promise(resolve => {
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
			resolve();
			return GLib.SOURCE_REMOVE;
		});
	});
}

async function enable(manager, uuid) {
	const deadline = GLib.get_monotonic_time() + 8 * GLib.USEC_PER_SEC;
	let extension = manager.lookup(uuid);
	while ((extension == null || extension.state == null)
			&& GLib.get_monotonic_time() < deadline) {
		await delay(200);
		extension = manager.lookup(uuid);
	}
	global.settings.set_boolean('disable-user-extensions', false);
	await manager._callExtensionEnable(uuid);
	extension = manager.lookup(uuid);
	const state = extension == null ? 'missing' : extension.state;
	smokeLog(uuid + ' state=' + state);
	if (state !== ExtensionState.ACTIVE)
		throw new Error('miss enable ' + uuid + ' state=' + state);
}

function runningHas(app) {
	const running = Shell.AppSystem.get_default().get_running();
	if (running == null)
		return false;
	for (let i = 0; i < running.length; i++) {
		if (running[i] === app)
			return true;
	}
	return false;
}

function desktopWindows() {
	const windows = global.display.list_all_windows();
	const list = windows != null ? windows : [];
	const found = [];
	for (const window of list) {
		if (window == null)
			continue;
		const title = typeof window.get_title === 'function'
			? window.get_title()
			: window.title;
		if (title != null && title.startsWith('Desktop Icons'))
			found.push(window);
	}
	return found;
}

function describe(window) {
	const title = typeof window.get_title === 'function'
		? window.get_title()
		: window.title;
	const type = typeof window.get_window_type === 'function'
		? window.get_window_type()
		: window.window_type;
	const skip = window.skip_taskbar;
	const app = Shell.WindowTracker.get_default().get_window_app(window);
	const name = app != null ? app.get_name() : 'none';
	const state = app != null ? app.state : 'none';
	const listed = app != null ? runningHas(app) : false;
	return 'title=' + title
		+ ' type=' + type
		+ ' skip=' + skip
		+ ' app=' + name
		+ ' state=' + state
		+ ' listed=' + listed;
}

async function run(main) {
	await enable(main.extensionManager, DING);
	await delay(6000);
	const found = desktopWindows();
	smokeLog('desktops=' + found.length);
	for (const window of found)
		smokeLog(describe(window));
	if (found.length !== 1) {
		smokeLog('miss desktops=' + found.length);
		return;
	}
	const app = Shell.WindowTracker.get_default().get_window_app(found[0]);
	if (app != null && (app.state !== Shell.AppState.STOPPED || runningHas(app))) {
		smokeLog('miss listed app=' + app.get_name()
			+ ' state=' + app.state);
		return;
	}
	smokeLog('ok');
}

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => run(main));
		}).catch(e => {
			smokeLog('miss ' + formatError(e));
			global.context.terminate();
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
