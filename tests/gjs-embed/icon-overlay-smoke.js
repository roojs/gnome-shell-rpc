/**
 * Guest session after Shell.WM.map: desktop-cube writes NaN
 * translation-x / translation-z / rotation-angle-y, and Desktop
 * Icons' set_type hits a read-only window-type. This boots the
 * shell with both extensions so that log can show up here.
 *
 *   GSR_NESTED_TIMEOUT=80 GI_META_SMOKE=icon-overlay/ui/init \
 *     ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { GLib, Gio } = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';
import {ExtensionState} from 'resource:///org/gnome/shell/misc/extensionUtils.js';

const SMOKE = 'icon-overlay/ui/init';
const CUBE = 'desktop-cube@schneegans.github.com';
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

function cubeDepth() {
	const perspective = global.stage.perspective;
	const fovy = perspective.fovy;
	const mon = global.display.get_monitor_geometry(0);
	const camDist = mon.height / (2 * Math.tan(fovy / 2 * Math.PI / 180));
	const centerDepth = mon.width / 2;
	const vDepthOffset = 1.1 * (2 * centerDepth) * camDist / mon.width - centerDepth;
	return 'fovy=' + fovy + ' mon=' + mon.width + 'x' + mon.height
		+ ' depth=' + vDepthOffset;
}

function logWindows() {
	const windows = global.display.list_all_windows();
	const list = windows != null ? windows : [];
	let n = 0;
	for (const w of list) {
		if (w == null)
			continue;
		n += 1;
		const title = w.get_title != null ? w.get_title() : w.title;
		const type = w.get_window_type != null ? w.get_window_type() : w.window_type;
		smokeLog('window type=' + type + ' title=' + title);
	}
	smokeLog('windows=' + n);
}

async function run(main) {
	const manager = main.extensionManager;
	global.window_manager.connect_after('map', (_wm, actor) => {
		const window = actor.meta_window;
		const type = window != null && window.get_window_type != null
			? window.get_window_type()
			: 'none';
		smokeLog('map scale=' + actor.scale_x + 'x' + actor.scale_y
			+ ' type=' + type);
	});
	await enable(manager, CUBE);
	await enable(manager, DING);
	await delay(5000);
	const before = cubeDepth();
	smokeLog('before ' + before);
	logWindows();
	if (before.indexOf('depth=NaN') >= 0 || before.indexOf('depth=Infinity') >= 0)
		throw new Error('miss nan-depth ' + before);
	main.overview.show();
	await delay(2000);
	const after = cubeDepth();
	smokeLog('overview ' + after);
	logWindows();
	if (after.indexOf('depth=NaN') >= 0 || after.indexOf('depth=Infinity') >= 0)
		throw new Error('miss nan-depth ' + after);
	const {St} = imports.gi;
	const scale = St.ThemeContext.get_for_stage(global.stage).scale_factor;
	const mon = global.display.get_monitor_geometry(0);
	const wsm = global.workspace_manager;
	smokeLog('switch scale=' + scale + ' mon=' + mon.width + 'x' + mon.height
		+ ' rows=' + wsm.layout_rows + ' n=' + wsm.n_workspaces);
	if (wsm.n_workspaces < 2)
		wsm.append_new_workspace(false, global.get_current_time());
	wsm.get_workspace_by_index(1).activate(global.get_current_time());
	await delay(2000);
	smokeLog('switched n=' + wsm.n_workspaces
		+ ' active=' + wsm.get_active_workspace_index());
	smokeLog('done');
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
