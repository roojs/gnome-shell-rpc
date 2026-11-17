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

function actorChain(actor) {
	const parts = [];
	let cur = actor;
	while (cur != null) {
		const nm = cur.name ? ('#' + cur.name) : '';
		parts.push(cur.constructor.name + nm + (cur.reactive ? '[R]' : ''));
		cur = cur.get_parent();
	}
	return parts.join(' -> ');
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
	await delay(600);
}

async function run(main) {
	const manager = main.extensionManager;
	if (manager._initializationPromise)
		await manager._initializationPromise;
	// Wait for DING startup so it doesn't activate mid-overview and hide it.
	for (let i = 0; i < 20; i++) {
		const hasDing = global.get_window_actors().some(
			a => a.meta_window?.title?.includes('Desktop Icons'));
		if (hasDing)
			break;
		await delay(250);
	}
	await delay(500);
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
	if (extension.state !== ExtensionState.ACTIVE)
		await manager._callExtensionEnable(UUID);
	extension = manager.lookup(UUID);
	const state = extension == null ? 'missing' : extension.state;
	const errs = JSON.stringify(extension?.errors ?? []);
	smokeLog('extension-state=' + state + ' hasStateObj=' + (extension?.stateObj != null)
		+ ' errs=' + errs);
	if (extension == null || extension.stateObj == null)
		throw new Error('miss enable-state=' + state + ' errs=' + errs);

	const cube = extension.stateObj;
	const origDepth = cube._depthSortCubeFaces.bind(cube);
	cube._depthSortCubeFaces = function(actors) {
		const parent = actors?.[0]?.get_parent() ?? null;
		if (parent == null)
			return;
		return origDepth(actors);
	};

	const ViewProto = imports.ui.workspacesView.WorkspacesView.prototype;
	const origState = ViewProto._updateWorkspacesState;
	let stateLogs = 0;
	ViewProto._updateWorkspacesState = function() {
		const ws = this._workspaces?.[0];
		const parent = ws?.get_parent() ?? null;
		if (ws != null && parent == null && stateLogs < 4) {
			stateLogs++;
			let nChildren = -1;
			let inKids = false;
			let viewParent = false;
			let err = '';
			try {
				nChildren = this.get_n_children();
				viewParent = this.get_parent() != null;
				inKids = this.get_children().indexOf(ws) >= 0;
			} catch (e) {
				err = '' + e;
			}
			smokeLog('state NULL n=' + this._workspaces.length
				+ ' kids=' + nChildren
				+ ' inKids=' + inKids
				+ ' viewParent=' + viewParent
				+ ' viewStage=' + (this.get_stage() != null)
				+ ' err=' + err);
		}
		if (parent == null && this._workspaces?.length)
			return;
		return origState.apply(this, arguments);
	};

	const wm = global.workspace_manager;
	while (wm.n_workspaces < 4)
		wm.append_new_workspace(false, global.get_current_time());

	const St = imports.gi.St;
	const probeParent = new St.Widget({name: 'probe-parent'});
	const probeChild = new St.Widget({name: 'probe-child'});
	main.layoutManager.uiGroup.add_child(probeParent);
	probeParent.add_child(probeChild);
	const probeGot = probeChild.get_parent();
	smokeLog('probe parentNull=' + (probeGot == null)
		+ ' same=' + (probeGot === probeParent)
		+ ' name=' + (probeGot?.name ?? 'none'));
	probeParent.destroy();

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

	const deskTracker = main.wm._workspaceAnimation._swipeTracker;
	let panelBegan = 0;
	let panelUpdated = 0;
	let panelEnded = 0;
	const pbId = deskTracker.connect('begin', () => { panelBegan++; });
	const puId = deskTracker.connect('update', () => { panelUpdated++; });
	const peId = deskTracker.connect('end', () => { panelEnded++; });
	await dragRange(virt, 1200, 730, 10);
	deskTracker.disconnect(pbId);
	deskTracker.disconnect(puId);
	deskTracker.disconnect(peId);
	const activities = main.panel.statusArea?.activities;
	smokeLog('panel began=' + panelBegan + ' updated=' + panelUpdated
		+ ' ended=' + panelEnded + ' ws=' + wm.get_active_workspace_index()
		+ ' cgEnabled=' + main.panel._clickGesture?.enabled
		+ ' cgGetEnabled=' + main.panel._clickGesture?.get_enabled()
		+ ' activitiesGetEnabled=' + activities?._clickGesture?.get_enabled());
	const now = () => GLib.get_monotonic_time();
	virt.notify_absolute_motion(now(), 40, 10);
	await delay(50);
	virt.notify_button(now(), 1, Clutter.ButtonState.PRESSED);
	await delay(50);
	virt.notify_button(now(), 1, Clutter.ButtonState.RELEASED);
	await delay(400);
	smokeLog('activities-click vis=' + main.overview.visible);

	// 2. Overview drag.
	const ovDisplay = main.overview._overview._controls._workspacesDisplay;
	smokeLog('ov-before-show leaving=' + ovDisplay._leavingOverview + ' mapped=' + ovDisplay.mapped);
	main.overview.show();
	await delay(1000);
	const ws0 = ovDisplay._workspacesViews?.[0]?._workspaces?.[0];
	const wsParent = ws0?.get_parent() ?? null;
	smokeLog('ws parentNull=' + (wsParent == null)
		+ ' name=' + (wsParent?.name ?? 'none')
		+ ' n=' + (ovDisplay._workspacesViews?.[0]?._workspaces?.length ?? 0));
	const ovTracker = ovDisplay._swipeTracker;
	smokeLog('ov-state vis=' + main.overview.visible
		+ ' mode=' + main.actionMode
		+ ' ctrl=' + main.overview._overview.controls._stateAdjustment.value
		+ ' leaving=' + ovDisplay._leavingOverview
		+ ' trackerEnabled=' + ovTracker.enabled);
	let ovBegan = 0;
	let ovUpdated = 0;
	let ovEnded = 0;
	ovTracker.connect('begin', () => { ovBegan++; });
	ovTracker.connect('update', () => { ovUpdated++; });
	ovTracker.connect('end', () => { ovEnded++; });
	await dragRange(virt, 800, 240, 400);
	smokeLog('overview began=' + ovBegan + ' updated=' + ovUpdated
		+ ' ended=' + ovEnded + ' ws=' + wm.get_active_workspace_index());

	main.overview.hide();
	await delay(800);

	// 3. Desktop background. DING's maximized window usually covers
	// _backgroundGroup; this drag records whatever is actually picked.
	let deskBegan = 0;
	let deskUpdated = 0;
	let deskEnded = 0;
	const dbId = deskTracker.connect('begin', () => { deskBegan++; });
	const duId = deskTracker.connect('update', () => { deskUpdated++; });
	const deId = deskTracker.connect('end', () => { deskEnded++; });
	await dragRange(virt, 240, 800, 400);
	deskTracker.disconnect(dbId);
	deskTracker.disconnect(duId);
	deskTracker.disconnect(deId);
	smokeLog('desktop began=' + deskBegan + ' updated=' + deskUpdated
		+ ' ended=' + deskEnded + ' ws=' + wm.get_active_workspace_index());

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
