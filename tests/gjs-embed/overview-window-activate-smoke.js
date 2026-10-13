/**
 * Click an overview window thumbnail and check we actually land on
 * that window. A hand session left a slightly ghosted window after
 * this click, and dragging the same thumbnail between workspaces
 * does not start.
 *
 * Pass: `overview-window-activate-smoke: ok`
 * Fail: `overview-window-activate-smoke: miss <reason>`
 *
 *   GI_META_SMOKE=overview-window-activate-smoke \
 *   GI_META_SMOKE_CMD='gedit --new-window' \
 *   GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
 *   GSR_NESTED_TIMEOUT=90 \
 *   ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.Clutter = '16';

const { Gio, GLib, Meta, Shell } = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'overview-window-activate-smoke';
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
 * @param {object} actor
 * @returns {string}
 */
function actorBits(actor) {
	if (actor == null)
		return 'null';
	try {
		const mapped = actor.mapped ? 'mapped' : 'unmapped';
		const visible = actor.visible ? 'visible' : 'hidden';
		return 'opacity=' + actor.opacity
			+ ' scale=' + actor.scale_x + ',' + actor.scale_y
			+ ' ' + actor.width + 'x' + actor.height
			+ ' ' + mapped + ' ' + visible;
	} catch (e) {
		return 'threw ' + formatError(e);
	}
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
	const actor = win.get_compositor_private();
	smokeLog('window title=' + JSON.stringify(title)
		+ ' before ' + actorBits(actor));
	if (actor == null)
		throw new Error('miss actor');

	main.overview.show();
	const visDeadline = GLib.get_monotonic_time() + 8 * GLib.TIME_SPAN_SECOND;
	while (!main.overview.visible && GLib.get_monotonic_time() < visDeadline)
		await delay(100);
	if (!main.overview.visible)
		throw new Error('miss overview');
	await delay(800);

	const previews = findPreviews(globalObj.stage, 0, []);
	let preview = null;
	const titles = [];
	for (const candidate of previews) {
		let candidateTitle = '?';
		try {
			candidateTitle = candidate.metaWindow != null
				? String(candidate.metaWindow.get_title())
				: '(no metaWindow)';
		} catch (e) {
			candidateTitle = '(threw)';
		}
		titles.push(candidateTitle);
		if (candidateTitle === title)
			preview = candidate;
	}
	smokeLog('previews=' + previews.length
		+ ' titles=' + JSON.stringify(titles)
		+ ' matched=' + (preview != null));
	if (preview == null)
		throw new Error('miss preview');

	let selected = false;
	preview.connect('selected', () => {
		selected = true;
	});
	const [x, y] = preview.get_transformed_position();
	const [w, h] = preview.get_transformed_size();
	const cx = x + w / 2;
	const cy = y + h / 2;
	smokeLog('click ' + cx + ',' + cy + ' size=' + w + 'x' + h
		+ ' preview ' + actorBits(preview));
	globalObj.pointer_click(cx, cy);

	const hideDeadline = GLib.get_monotonic_time() + 3 * GLib.TIME_SPAN_SECOND;
	while (main.overview.visible && GLib.get_monotonic_time() < hideDeadline)
		await delay(100);
	await delay(400);

	const focus = display.get_focus_window();
	let focusTitle = '(none)';
	try {
		focusTitle = focus != null ? focus.get_title() : '(none)';
	} catch (e) {
		focusTitle = '(threw)';
	}
	let inDrag = '?';
	try {
		inDrag = String(preview.inDrag);
	} catch (e) {
		inDrag = 'threw';
	}
	smokeLog('after selected=' + selected
		+ ' overview=' + main.overview.visible
		+ ' focus=' + JSON.stringify(focusTitle)
		+ ' inDrag=' + inDrag
		+ ' actor ' + actorBits(actor)
		+ ' preview ' + actorBits(preview));

	if (main.overview.visible)
		throw new Error('miss overview-stayed');
	if (!selected)
		throw new Error('miss selected');
	if (focusTitle !== title)
		throw new Error('miss focus');
	if (inDrag === 'true')
		throw new Error('miss drag-on-click');
	if (actor.opacity < 250)
		throw new Error('miss ghost-opacity=' + actor.opacity);
	if (actor.scale_x < 0.9 || actor.scale_y < 0.9)
		throw new Error('miss ghost-scale=' + actor.scale_x + ',' + actor.scale_y);
	try {
		if (preview.mapped && preview.opacity < 250)
			throw new Error('miss ghost-preview opacity=' + preview.opacity);
	} catch (e) {
		if (String(e).indexOf('miss ghost-preview') >= 0)
			throw e;
	}
	smokeLog('ok');
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(async main => {
			// This smoke starts main.js directly, so it does not take the
			// shell-startup frame lock used by gsr-client. Keep PanelMenu's
			// add-then-hide RPC gap from aborting on the unrelated empty
			// Quick Settings layout.
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
