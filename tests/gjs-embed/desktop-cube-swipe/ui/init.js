/**
 * Enable desktop-cube and drag horizontally in the overview, on the
 * desktop background, and on the top panel to check that the cube
 * swipe rotates workspaces without crashing.
 *
 * Pass: `desktop-cube-swipe/ui/init: ok`
 * Fail: `desktop-cube-swipe/ui/init: miss <reason>`
 */

imports.gi.versions.Meta = GLib_version();
function GLib_version() {
	try {
		imports.gi.versions.Meta = '18';
		const _m = imports.gi.Meta;
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

const SMOKE = 'desktop-cube-swipe/ui/init';
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

async function dragAcross(virt, y, direction) {
	const now = () => GLib.get_monotonic_time();
	const startX = direction < 0 ? 800 : 240;
	virt.notify_absolute_motion(now(), startX, y);
	await delay(50);
	virt.notify_button(now(), 1, Clutter.ButtonState.PRESSED);
	await delay(50);
	for (let step = 1; step <= 14; step++) {
		virt.notify_absolute_motion(now(), startX + direction * step * 40, y);
		await delay(30);
	}
	virt.notify_button(now(), 1, Clutter.ButtonState.RELEASED);
	await delay(600);
}

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
	smokeLog('extension-state=' + state + ' hasStateObj=' + (extension?.stateObj != null));
	if (extension == null || extension.stateObj == null)
		throw new Error('miss enable-state=' + state);

	const wm = global.workspace_manager;
	while (wm.n_workspaces < 4)
		wm.append_new_workspace(false, global.get_current_time());

	const seat = Clutter.get_default_backend().get_default_seat();
	const virt = seat.create_virtual_device(
		Clutter.InputDeviceType.POINTER_DEVICE);

	const dg = extension.stateObj._desktopDragGesture?.gesture;
	if (dg != null) {
		const origHandle = dg.constructor.prototype._handleEvent;
		dg.constructor.prototype._handleEvent = function(event) {
			const tag = this._actor === main.panel
				? 'panel'
				: (this._actor === main.layoutManager._backgroundGroup ? 'bg' : 'ov');
			const pre = this._state;
			const res = origHandle.call(this, event);
			smokeLog('ev ' + tag + ' type=' + event.type()
				+ ' state=' + event.get_state()
				+ ' coords=' + event.get_coords()
				+ ' ' + pre + '->' + this._state
				+ ' grab=' + (this._lastGrab != null));
			return res;
		};
	}

	main.overview.show();
	await delay(800);
	const ovTracker =
		main.overview._overview._controls._workspacesDisplay._swipeTracker;
	let ovBegan = 0;
	let ovUpdated = 0;
	let ovEnded = 0;
	ovTracker.connect('begin', () => {
		ovBegan++;
	});
	ovTracker.connect('update', () => {
		ovUpdated++;
	});
	ovTracker.connect('end', () => {
		ovEnded++;
	});

	await dragAcross(virt, 400, -1);
	const ovWs = wm.get_active_workspace_index();
	smokeLog('overview began=' + ovBegan + ' updated=' + ovUpdated
		+ ' ended=' + ovEnded + ' ws=' + ovWs);

	main.overview.hide();
	await delay(800);

	const deskTracker = main.wm._workspaceAnimation._swipeTracker;
	let deskBegan = 0;
	let deskUpdated = 0;
	let deskEnded = 0;
	deskTracker.connect('begin', () => {
		deskBegan++;
	});
	deskTracker.connect('update', () => {
		deskUpdated++;
	});
	deskTracker.connect('end', () => {
		deskEnded++;
	});

	await dragAcross(virt, 400, 1);
	const deskWs = wm.get_active_workspace_index();
	smokeLog('desktop began=' + deskBegan + ' updated=' + deskUpdated
		+ ' ended=' + deskEnded + ' ws=' + deskWs);

	let panelBegan = 0;
	let panelUpdated = 0;
	let panelEnded = 0;
	deskTracker.connect('begin', () => {
		panelBegan++;
	});
	deskTracker.connect('update', () => {
		panelUpdated++;
	});
	deskTracker.connect('end', () => {
		panelEnded++;
	});

	await dragAcross(virt, 10, -1);
	const panelWs = wm.get_active_workspace_index();
	smokeLog('panel began=' + panelBegan + ' updated=' + panelUpdated
		+ ' ended=' + panelEnded + ' ws=' + panelWs);

	if (ovBegan < 1 || ovUpdated < 1)
		throw new Error('miss overview-swipe');
	if (deskBegan < 1 || deskUpdated < 1)
		throw new Error('miss desktop-swipe');
	if (panelBegan < 1 || panelUpdated < 1)
		throw new Error('miss panel-swipe');
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
