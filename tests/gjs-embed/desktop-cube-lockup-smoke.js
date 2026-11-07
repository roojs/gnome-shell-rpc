/**
 * Enabling desktop-cube calls get_parent() on the first workspace
 * actor and then set_child_at_index. On the Ubuntu session that
 * parent was null and the shell locked up.
 *
 * Pass: `desktop-cube-lockup/ui/init: ok`
 * Fail: `desktop-cube-lockup/ui/init: miss <reason>`
 *
 *   GSR_NESTED_TIMEOUT=70 GI_META_SMOKE=desktop-cube-lockup/ui/init \
 *     ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.Clutter = '16';

const { GLib, Gio } = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';
import {ExtensionState} from 'resource:///org/gnome/shell/misc/extensionUtils.js';

const SMOKE = 'desktop-cube-lockup/ui/init';
const UUID = 'desktop-cube@schneegans.github.com';

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
 * @param {object} main
 */
async function run(main) {
	const manager = main.extensionManager;
	const deadline = GLib.get_monotonic_time() + 8 * GLib.USEC_PER_SEC;
	let extension = manager.lookup(UUID);
	while ((extension == null || extension.state == null)
		&& GLib.get_monotonic_time() < deadline) {
		await delay(200);
		extension = manager.lookup(UUID);
	}
	if (extension == null || extension.state == null)
		throw new Error('miss extension-not-loaded');
	global.settings.set_boolean('disable-user-extensions', false);
	await manager._callExtensionEnable(UUID);
	extension = manager.lookup(UUID);
	const state = extension == null ? 'missing' : extension.state;
	smokeLog('extension-state=' + state);
	if (state !== ExtensionState.ACTIVE)
		throw new Error('miss enable-state=' + state);

	const wm = global.workspace_manager;
	if (wm.n_workspaces < 2)
		wm.append_new_workspace(false, global.get_current_time());
	main.overview.show();
	await delay(800);
	const display = main.overview._overview.controls._workspacesDisplay;
	const views = display._workspacesViews;
	if (views == null || views.length < 1)
		throw new Error('miss no-workspaces-view');
	const view = views[0];
	const workspaces = view._workspaces;
	if (workspaces == null || workspaces.length < 1)
		throw new Error('miss no-workspace-actor');
	const first = workspaces[0];
	let parent = null;
	try {
		parent = first.get_parent();
	} catch (e) {
		throw new Error('miss get_parent ' + e);
	}
	const parentName = parent == null ? 'null' : parent;
	smokeLog('workspaces=' + workspaces.length + ' parent=' + parentName);
	if (parent == null)
		throw new Error('miss parent-null');
	smokeLog('ok');
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => run(main));
		}).then(() => {
			smokeLog('done');
			global.context.terminate();
		}).catch(e => {
			smokeLog('miss ' + formatError(e));
			smokeLog('done');
			const error = new GLib.Error(
				Gio.IOErrorEnum, Gio.IOErrorEnum.FAILED, formatError(e));
			global.context.terminate_with_error(error);
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
