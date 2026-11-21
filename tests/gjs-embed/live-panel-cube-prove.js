/**
 * Real logged-in Wayland session (not headless): panel drag must rotate
 * workspaces. Spawn with:
 *   systemctl --user set-environment GI_META_SMOKE=live-panel-cube-prove
 *   systemctl --user restart org.gnome.ShellRpc@wayland.service
 *
 * Pass: `live-panel-cube-prove: ok`
 * Fail: `live-panel-cube-prove: miss <reason>`
 */

imports.gi.versions.Meta = GLib_version();
function GLib_version() {
	try {
		imports.gi.versions.Meta = '18';
		imports.gi.Meta;
		return '18';
	} catch (e) {
		imports.gi.versions.Meta = '16';
		return '16';
	}
}
imports.gi.versions.Shell = imports.gi.versions.Meta;
imports.gi.versions.Clutter = imports.gi.versions.Meta;

const { GLib, Clutter } = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';
import {ExtensionState} from 'resource:///org/gnome/shell/misc/extensionUtils.js';

const SMOKE = 'live-panel-cube-prove';
const UUID = 'desktop-cube@schneegans.github.com';

function smokeLog(message) {
	console.log(SMOKE + ': ' + message);
}

function delay(ms) {
	return new Promise(resolve => {
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
			resolve();
			return GLib.SOURCE_REMOVE;
		});
	});
}

async function dragRange(virt, startX, endX, y, steps = 14) {
	const now = () => GLib.get_monotonic_time();
	const dx = (endX - startX) / steps;
	virt.notify_absolute_motion(now(), startX, y);
	await delay(50);
	virt.notify_button(now(), 1, Clutter.ButtonState.PRESSED);
	await delay(50);
	for (let step = 1; step <= steps; step++) {
		virt.notify_absolute_motion(now(), Math.round(startX + dx * step), y);
		await delay(30);
	}
	virt.notify_button(now(), 1, Clutter.ButtonState.RELEASED);
	await delay(800);
}

async function run(main) {
	const manager = main.extensionManager;
	if (manager._initializationPromise)
		await manager._initializationPromise;
	for (let i = 0; i < 40; i++) {
		if (global.stage != null && global.stage.context != null)
			break;
		await delay(250);
	}
	if (global.stage == null || global.stage.context == null)
		throw new Error('miss stage-not-ready');
	await delay(1500);

	let extension = manager.lookup(UUID);
	if (extension == null || extension.state === ExtensionState.INITIALIZED)
		global.settings.set_boolean('disable-user-extensions', false);
	if (extension != null && extension.state !== ExtensionState.ACTIVE)
		await manager._callExtensionEnable(UUID);
	extension = manager.lookup(UUID);
	if (extension == null || extension.stateObj == null)
		throw new Error('miss extension');

	const wm = global.workspace_manager;
	while (wm.n_workspaces < 4)
		wm.append_new_workspace(false, global.get_current_time());

	if (main.overview.visible) {
		main.overview.hide();
		await delay(800);
	}

	const before = wm.get_active_workspace_index();
	const deskTracker = main.wm._workspaceAnimation._swipeTracker;
	let panelBegan = 0;
	let panelUpdated = 0;
	let panelEnded = 0;
	const pbId = deskTracker.connect('begin', () => { panelBegan++; });
	const puId = deskTracker.connect('update', () => { panelUpdated++; });
	const peId = deskTracker.connect('end', () => { panelEnded++; });

	const seat = Clutter.get_default_backend().get_default_seat();
	const virt = seat.create_virtual_device(
		Clutter.InputDeviceType.POINTER_DEVICE);
	await dragRange(virt, 1200, 730, 10);

	deskTracker.disconnect(pbId);
	deskTracker.disconnect(puId);
	deskTracker.disconnect(peId);

	const after = wm.get_active_workspace_index();
	smokeLog('panel began=' + panelBegan + ' updated=' + panelUpdated
		+ ' ended=' + panelEnded + ' ws-before=' + before + ' ws-after=' + after);

	if (panelBegan < 1 || panelUpdated < 1)
		throw new Error('miss panel-swipe');
	if (after === before)
		throw new Error('miss workspace-switch');
	smokeLog('ok');
}

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => run(main));
		}).then(() => {
			global.context.terminate();
		}).catch(e => {
			smokeLog('miss ' + formatError(e));
			global.context.terminate();
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});