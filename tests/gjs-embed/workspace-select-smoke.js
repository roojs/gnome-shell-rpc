/**
 * Overview workspace click should slide the chosen workspace into
 * the middle. Stock does that from Shell.WM::switch-workspace, which
 * eases the workspace scroll adjustment. This smoke activates a
 * non-active workspace while the overview is shown and checks that
 * the adjustment moves.
 *
 * Pass: `workspace-select-smoke: ok`
 * Fail: `workspace-select-smoke: miss <reason>`
 *
 *   GSR_NESTED_TIMEOUT=70 GI_META_SMOKE=workspace-select-smoke \
 *     ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.Clutter = '16';

const { GLib, Gio } = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'workspace-select-smoke';

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
	const manager = global.workspace_manager;
	if (manager.n_workspaces < 2)
		manager.append_new_workspace(false, global.get_current_time());
	if (manager.n_workspaces < 2)
		throw new Error('miss workspaces (still ' + manager.n_workspaces + ')');

	main.overview.show();
	await delay(400);
	if (!main.overview.visible)
		throw new Error('miss overview (not visible)');

	const active = manager.get_active_workspace_index();
	const target = active === 0 ? 1 : 0;
	const workspace = manager.get_workspace_by_index(target);
	if (workspace == null)
		throw new Error('miss workspace (index ' + target + ')');

	const adjustment = main.overview._overview.controls._workspaceAdjustment;
	const before = adjustment.value;
	let sawSwitch = false;
	global.window_manager.connect('switch-workspace', () => {
		sawSwitch = true;
	});

	workspace.activate(global.get_current_time());
	await delay(500);

	const after = adjustment.value;
	smokeLog('before=' + before + ' after=' + after
		+ ' target=' + target + ' switch=' + sawSwitch
		+ ' active=' + manager.get_active_workspace_index());
	if (!sawSwitch)
		throw new Error('miss switch-workspace (signal never emitted)');
	if (Math.abs(after - target) > 0.05)
		throw new Error('miss scroll (value ' + after + ' target ' + target + ')');
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
