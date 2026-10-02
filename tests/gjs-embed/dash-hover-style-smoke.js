/**
 * Reproduce the 15:09 crash path.
 *
 * Full shell: app-grid _redisplay → BaseIcon.vfunc_style_changed
 * (iconGrid.js super) → dash notify::hover → shouldShowTooltip
 * reads hover → AppIcon.vfunc_leave_event → style_changed again.
 * style-reenter-smoke never starts that shell. This one does.
 *
 * A depth above 2 is the failure (the crash was 67 frames). The
 * counter stops at DEPTH_LIMIT so the log is written instead of
 * the client dying in the signal emit.
 *
 *   GSR_NESTED_TIMEOUT=90 GI_META_SMOKE=dash-hover-style-smoke \
 *     ./scripts/agent-nested-smoke-prove.sh
 */

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Clutter from 'gi://Clutter';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'dash-hover-style-smoke';
const DEPTH_LIMIT = 6;

const state = {
	entered: 0,
	completed: 0,
	maxDepth: 0,
	depth: 0,
	leave: 0,
	hoverRead: 0,
	hitLimit: false,
	stack: '',
	error: '',
	poked: false,
	poke: '',
};

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

/**
 * @param {object} iconGrid
 * @param {object} appDisplay
 */
function patch(iconGrid, appDisplay) {
	const iconProto = iconGrid.BaseIcon.prototype;
	const origStyle = iconProto.vfunc_style_changed;
	iconProto.vfunc_style_changed = function () {
		state.entered++;
		state.depth++;
		if (state.depth > state.maxDepth)
			state.maxDepth = state.depth;
		if (state.depth > DEPTH_LIMIT) {
			state.hitLimit = true;
			if (state.stack.length === 0)
				state.stack = new Error('depth').stack;
			state.depth--;
			return;
		}
		try {
			origStyle.apply(this, arguments);
			state.completed++;
		} catch (e) {
			state.error = String(e);
			if (state.stack.length === 0)
				state.stack = e.stack || String(e);
		} finally {
			state.depth--;
		}
	};

	const appProto = appDisplay.AppIcon.prototype;
	const origLeave = appProto.vfunc_leave_event;
	appProto.vfunc_leave_event = function (event) {
		state.leave++;
		return origLeave.apply(this, arguments);
	};
}

/**
 * @param {object} actor
 * @returns {number[]}
 */
function centerOf(actor) {
	const [x, y] = actor.get_transformed_position();
	return [x + actor.width / 2, y + actor.height / 2];
}

/**
 * @param {number} x
 * @param {number} y
 */
function movePointer(x, y) {
	const backend = Clutter.get_default_backend();
	const seat = backend.get_default_seat();
	const virt = seat.create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);
	virt.notify_absolute_motion(0, x, y);
}

function finish(why) {
	smokeLog(`why=${why} entered=${state.entered} completed=${state.completed} ` +
		`maxDepth=${state.maxDepth} leave=${state.leave} hoverRead=${state.hoverRead} ` +
		`hitLimit=${state.hitLimit} poke=${state.poke} error=${state.error}`);
	if (state.stack.length > 0)
		smokeLog('stack ' + state.stack.split('\n').slice(0, 12).join(' | '));
	if (state.hitLimit || state.maxDepth > 2 || state.error.length > 0)
		smokeLog('miss');
	else if (state.entered < 1)
		smokeLog('miss');
	else
		smokeLog('ok');
}

/**
 * @param {object} main
 */
function afterStart(main) {
	const dash = main.overview.dash;
	const items = dash._box.get_children();
	let target = dash._showAppsIcon?.toggleButton ?? null;
	if (items.length > 0 && items[0].child)
		target = items[0].child;
	let moved = false;
	if (target != null && target.width > 0 && target.height > 0) {
		const [x, y] = centerOf(target);
		movePointer(x, y);
		moved = true;
		smokeLog(`pointer ${x.toFixed(0)},${y.toFixed(0)} items=${items.length}`);
	} else {
		smokeLog(`no-pointer items=${items.length} ` +
			`target=${target != null} w=${target ? target.width : 0}`);
	}

	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 400, () => {
		try {
			if (target != null) {
				state.hoverRead++;
				void target.hover;
				target.sync_hover();
			}
			main.overview.controls.appDisplay._redisplay();
			const icon = target?.icon ?? dash._showAppsIcon?.icon;
			if (icon)
				icon.set_style('padding: 1px;');
		} catch (e) {
			state.error = formatError(e);
		}
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, 600, () => {
			finish(moved ? 'after-pointer' : 'after-redisplay');
			return GLib.SOURCE_REMOVE;
		});
		return GLib.SOURCE_REMOVE;
	});
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return Promise.all([
				import('resource:///org/gnome/shell/ui/iconGrid.js'),
				import('resource:///org/gnome/shell/ui/appDisplay.js'),
			]).then(([iconGrid, appDisplay]) => {
				patch(iconGrid, appDisplay);
				global.main = main;
				return main.start().then(() => main);
			});
		}).then(main => {
			smokeLog('started');
			afterStart(main);
		}).catch(e => {
			state.error = formatError(e);
			finish('start');
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
