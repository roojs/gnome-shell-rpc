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
	let ended = false;
	preview.connect('drag-begin', () => {
		began = true;
	});
	preview.connect('drag-end', () => {
		ended = true;
	});
	const [x, y] = preview.get_transformed_position();
	const [w, h] = preview.get_transformed_size();
	const cx = x + w / 2;
	const cy = y + h / 2;
	smokeLog('drag ' + cx + ',' + cy + ' size=' + w + 'x' + h);
	if (GLib.getenv('GI_META_SMOKE_MANUAL') === '1') {
		smokeLog('manual-ready');
		const manualDeadline =
			GLib.get_monotonic_time() + 30 * GLib.TIME_SPAN_SECOND;
		while (!began && GLib.get_monotonic_time() < manualDeadline)
			await delay(100);
		if (!began)
			throw new Error('miss manual-drag-begin');
		smokeLog('ok');
		return;
	}

	const seat = Clutter.get_default_backend().get_default_seat();
	const virt = seat.create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);
	const now = () => GLib.get_monotonic_time();
	virt.notify_absolute_motion(now(), cx, cy);
	await delay(50);
	virt.notify_button(now(), 1, Clutter.ButtonState.PRESSED);
	await delay(50);
	const stayInside = GLib.getenv('GI_META_SMOKE_STAY_INSIDE') === '1';
	const startX = stayInside ? cx + 80 : x + w + 80;
	const startY = stayInside ? cy : y + h + 80;
	/* The default crosses the preview boundary; stay-inside reproduces the
	 * path where actor motion used to disappear after the press. */
	virt.notify_absolute_motion(now(), startX, startY);
	await delay(100);
	/* Continue beyond the 250ms drag scale transition. The earlier smoke
	 * stopped after one early displacement and never tested this path. */
	let movedX = x;
	let firstDx = null;
	for (let offset = 20; offset <= 200; offset += 20) {
		virt.notify_absolute_motion(
			now(), startX + offset, stayInside ? startY : startY + offset);
		await delay(100);
		[movedX] = preview.get_transformed_position();
		const dx = movedX - x;
		if (firstDx === null)
			firstDx = dx;
		smokeLog('motion offset=' + offset + ' dx=' + dx);
	}
	const tracked = (movedX - x) - firstDx;
	smokeLog('after began=' + began + ' inDrag=' + preview.inDrag
		+ ' dx=' + (movedX - x) + ' tracked=' + tracked);
	if (!began)
		throw new Error('miss drag-begin');
	if (Math.abs(movedX - x) < 30)
		throw new Error('miss preview-moved dx=' + (movedX - x));
	if (tracked < 30)
		throw new Error('miss preview-tracked dx=' + (movedX - x)
			+ ' first=' + firstDx);
	virt.notify_button(now(), 1, Clutter.ButtonState.RELEASED);
	const endDeadline =
		GLib.get_monotonic_time() + 3 * GLib.TIME_SPAN_SECOND;
	while (!ended && GLib.get_monotonic_time() < endDeadline)
		await delay(100);
	if (!ended || preview.inDrag)
		throw new Error('miss drag-end ended=' + ended
			+ ' inDrag=' + preview.inDrag);
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
