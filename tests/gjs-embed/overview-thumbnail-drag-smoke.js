/**
 * Press a window preview and move. The hand drag threw
 * `event is null` inside long-press cancel and never set inDrag.
 *
 * Pass: `overview-thumbnail-drag-smoke: ok`
 * Fail: `overview-thumbnail-drag-smoke: miss <reason>`
 *
 *   GI_META_SMOKE=overview-thumbnail-drag-smoke \
 *   GI_META_SMOKE_CMD='gedit --new-window' \
 *   GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
 *   GSR_NESTED_TIMEOUT=90 \
 *   ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.Clutter = '16';

const { Gio, GLib, Meta, Shell, Clutter } = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'overview-thumbnail-drag-smoke';
const CMD = GLib.getenv('GI_META_SMOKE_CMD') || 'gedit --new-window';
const WAIT_MS = parseInt(GLib.getenv('GI_META_SMOKE_WAIT_MS') || '8000', 10);

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
function normalWindows(display) {
	const list = display.list_all_windows();
	const windows = list != null ? list : [];
	return windows.filter(w =>
		w != null && w.window_type === Meta.WindowType.NORMAL);
}

/**
 * @param {object} actor
 * @param {number} depth
 * @param {object[]} out
 * @returns {object[]}
 */
function findPreviews(actor, depth, out) {
	out = out || [];
	if (actor == null || depth > 14 || out.length > 40)
		return out;
	let name = '';
	try {
		name = actor.constructor != null ? String(actor.constructor.name) : '';
	} catch (e) {
		name = '';
	}
	if (name.indexOf('WindowPreview') >= 0) {
		out.push(actor);
		return out;
	}
	let children = [];
	try {
		children = actor.get_children ? actor.get_children() : [];
	} catch (e) {
		children = [];
	}
	for (const child of children)
		findPreviews(child, depth + 1, out);
	return out;
}

/**
 * @param {object} main
 */
async function run(main) {
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	if (display == null)
		throw new Error('miss display');

	const ctx = globalObj.create_app_launch_context(0, -1);
	if (GLib.getenv('GI_WAYLAND_LAUNCH_UNSET_DISPLAY') === '1')
		ctx.unsetenv('DISPLAY');
	ctx.unsetenv('WAYLAND_SOCKET');
	const app = Gio.AppInfo.create_from_commandline(
		CMD, null, Gio.AppInfoCreateFlags.NONE);
	if (app === null || !app.launch([], ctx))
		throw new Error('miss launch');

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	let wins = [];
	while (GLib.get_monotonic_time() < deadline) {
		wins = normalWindows(display);
		if (wins.length > 0)
			break;
		await delay(200);
	}
	if (wins.length === 0)
		throw new Error('miss window');
	const win = wins[wins.length - 1];
	const title = win.get_title();

	main.overview.show();
	const visDeadline = GLib.get_monotonic_time() + 8 * GLib.TIME_SPAN_SECOND;
	while (!main.overview.visible && GLib.get_monotonic_time() < visDeadline)
		await delay(100);
	if (!main.overview.visible)
		throw new Error('miss overview');
	await delay(800);

	const previews = findPreviews(globalObj.stage, 0, []);
	let preview = null;
	for (const candidate of previews) {
		let candidateTitle = '?';
		try {
			candidateTitle = candidate.metaWindow != null
				? String(candidate.metaWindow.get_title())
				: '(no metaWindow)';
		} catch (e) {
			candidateTitle = '(threw)';
		}
		if (candidateTitle === title)
			preview = candidate;
	}
	if (preview == null)
		throw new Error('miss preview');

	let began = false;
	preview.connect('drag-begin', () => {
		began = true;
	});
	/* St.Settings.enable-animations is not writable. The 14:40
	 * ease still ran for 250ms, so force that duration here. */
	const origDuration = Clutter.Actor.prototype.set_easing_duration;
	Clutter.Actor.prototype.set_easing_duration = function (msecs, params) {
		const next = params != null ? params : {};
		next.animationRequired = true;
		return origDuration.call(this, msecs, next);
	};
	/* dnd.js calls get_transition again after ease(). The hand
	 * session spent ~230ms there and the 250ms scale was gone. */
	let transitionGone = false;
	const origGetTransition = Clutter.Actor.prototype.get_transition;
	Clutter.Actor.prototype.get_transition = function (name) {
		const stack = new Error().stack || '';
		const directDrag = name === 'scale-x'
			&& stack.indexOf('/dnd.js:') >= 0
			&& stack.indexOf('environment.js') < 0;
		if (directDrag) {
			const end = GLib.get_monotonic_time() + 400 * 1000;
			while (GLib.get_monotonic_time() < end) {}
		}
		const transition = origGetTransition.call(this, name);
		if (directDrag && transition == null) {
			transitionGone = true;
			throw new Error('transition-gone');
		}
		return transition;
	};
	const [x, y] = preview.get_transformed_position();
	const [w, h] = preview.get_transformed_size();
	const cx = x + w / 2;
	const cy = y + h / 2;
	smokeLog('drag ' + cx + ',' + cy + ' size=' + w + 'x' + h);

	const seat = Clutter.get_default_backend().get_default_seat();
	const virt = seat.create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);
	const now = () => GLib.get_monotonic_time();
	virt.notify_absolute_motion(now(), cx, cy);
	await delay(50);
	virt.notify_button(now(), 1, Clutter.ButtonState.PRESSED);
	await delay(50);
	/* Past the preview. The hand drag cancels on that leave. */
	virt.notify_absolute_motion(now(), x + w + 80, y + h + 80);
	await delay(300);
	const [movedX] = preview.get_transformed_position();
	smokeLog('after began=' + began + ' inDrag=' + preview.inDrag
		+ ' dx=' + (movedX - x));
	if (transitionGone)
		throw new Error('transition-gone');
	if (!began)
		throw new Error('miss drag-begin');
	if (Math.abs(movedX - x) < 30)
		throw new Error('miss preview-moved dx=' + (movedX - x));
	smokeLog('ok');
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(async main => {
			const PanelMenu =
				await import('resource:///org/gnome/shell/ui/panelMenu.js');
			const setMenu = PanelMenu.Button.prototype.setMenu;
			PanelMenu.Button.prototype.setMenu = function (menu) {
				if (menu)
					menu.actor.hide();
				return setMenu.call(this, menu);
			};
			await main.start();
			return run(main);
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
