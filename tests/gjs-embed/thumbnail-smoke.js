/**
 * Overview thumbnail repro — docs/bugs/2026-10-06-overview-no-thumbnails.md
 *
 * Boots product main.start, launches one normal client window (gedit on the
 * nested mutter display, not a terminal), shows the overview in-process, then
 * checks the window actually has a painted picture behind it:
 *   - Meta NORMAL window appears with a real frame
 *   - WindowTracker has an app for it (no `app is null`)
 *   - get_compositor_private() stand-in has non-null content after paint
 *   - a WindowPreview actor exists under the overview with non-zero size
 *
 * Pass: `thumbnail-smoke: ok`
 * Fail: `thumbnail-smoke: miss <reason>` naming the first missing step.
 *
 *   GI_META_SMOKE=thumbnail-smoke \
 *   GI_META_SMOKE_CMD='gedit --new-window' \
 *   GI_WAYLAND_LAUNCH_UNSET_DISPLAY=1 \
 *   GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 *
 * No production code changes from this file. The fix that makes this pass
 * is what gets ported into src/.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { Gio, GLib, Meta, Shell } = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'thumbnail-smoke';
const CMD = GLib.getenv('GI_META_SMOKE_CMD') || 'gedit --new-window';
const WAIT_MS = parseInt(GLib.getenv('GI_META_SMOKE_WAIT_MS') || '8000', 10);
const PAINT_WAIT_MS = 2500;

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
function listWindows(display) {
	if (typeof display.list_all_windows === 'function') {
		const list = display.list_all_windows();
		return list != null ? list : [];
	}
	const focus = display.get_focus_window();
	return focus != null ? [focus] : [];
}

/**
 * @param {Meta.Display} display
 * @returns {Meta.Window[]}
 */
function normalWindows(display) {
	return listWindows(display).filter(w =>
		w != null && w.window_type === Meta.WindowType.NORMAL);
}

/**
 * Best-effort content check on the compositor-private stand-in.
 * @param {object} actor
 * @returns {string}
 */
function contentState(actor) {
	try {
		const c = actor.content;
		if (c == null)
			return 'content=null';
		const w = actor.width;
		const h = actor.height;
		return 'content=set ' + w + 'x' + h;
	} catch (e) {
		return 'content-threw ' + formatError(e);
	}
}

/**
 * Walk the stage for overview window previews (stock GJS WindowPreview).
 * @param {object} actor
 * @param {number} depth
 * @param {object[]} out
 * @returns {object[]}
 */
function findPreviews(actor, depth, out) {
	out = out || [];
	if (actor == null || depth > 12 || out.length > 50)
		return out;
	let name = '';
	try {
		name = actor.constructor != null ? actor.constructor.name : '';
	} catch (e) {
		name = '?';
	}
	if (name.indexOf('WindowPreview') >= 0) {
		let mw = null;
		try {
			mw = actor.metaWindow != null ? actor.metaWindow.get_title() : '(no metaWindow)';
		} catch (e) {
			mw = '(metaWindow-threw)';
		}
		let size = '?';
		try {
			size = actor.width + 'x' + actor.height;
		} catch (e) {
			size = '(size-threw)';
		}
		out.push({title: String(mw), size});
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
async function runThumbnailProve(main) {
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	if (display == null)
		throw new Error('Global.get_display() is null');

	smokeLog('cmd=' + CMD);
	const ctx = globalObj.create_app_launch_context(0, -1);
	if (GLib.getenv('GI_WAYLAND_LAUNCH_UNSET_DISPLAY') === '1') {
		ctx.unsetenv('DISPLAY');
		smokeLog('ctx: unset DISPLAY');
	}
	const app = Gio.AppInfo.create_from_commandline(
		CMD, null, Gio.AppInfoCreateFlags.NONE);
	if (app === null)
		throw new Error('create_from_commandline failed');
	const launched = app.launch([], ctx);
	smokeLog('launch returned ' + launched);
	if (!launched)
		throw new Error('Gio.AppInfo.launch returned false');

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	let wins = [];
	while (GLib.get_monotonic_time() < deadline) {
		wins = normalWindows(display);
		if (wins.length > 0)
			break;
		await delay(200);
	}
	smokeLog('windows-normal=' + wins.length);
	if (wins.length === 0)
		throw new Error('miss window (no Meta NORMAL window after launch)');

	const win = wins[wins.length - 1];
	let title = '(untitled)';
	let frame = '?';
	try {
		title = win.get_title();
	} catch (e) {
		title = '(title-threw ' + formatError(e) + ')';
	}
	try {
		const r = win.get_frame_rect();
		frame = r.x + ',' + r.y + ' ' + r.width + 'x' + r.height;
	} catch (e) {
		frame = '(frame-threw ' + formatError(e) + ')';
	}
	smokeLog('window title=' + JSON.stringify(title) + ' frame=' + frame);
	if (frame.indexOf(' 0x0') >= 0)
		throw new Error('miss frame (window never got a size)');

	const tracker = Shell.WindowTracker.get_default();
	let wapp = null;
	try {
		wapp = tracker.get_window_app(win);
	} catch (e) {
		throw new Error('miss app (get_window_app threw ' + formatError(e) + ')');
	}
	smokeLog('window-app=' + (wapp == null ? 'null' : 'set'));
	if (wapp == null)
		throw new Error('miss app (get_window_app null — preview would throw)');

	let priv = null;
	try {
		priv = win.get_compositor_private();
	} catch (e) {
		throw new Error('miss actor (get_compositor_private threw ' + formatError(e) + ')');
	}
	smokeLog('compositor-private=' + (priv == null ? 'null' : contentState(priv)));

	smokeLog('show overview');
	main.overview.show();
	const visDeadline = GLib.get_monotonic_time() + 15 * GLib.TIME_SPAN_SECOND;
	while (!main.overview.visible && GLib.get_monotonic_time() < visDeadline)
		await delay(200);
	smokeLog('overview.visible=' + main.overview.visible);
	if (!main.overview.visible)
		throw new Error('miss overview (never visible)');

	// Let size-changed + preview_actor repaint land.
	await delay(PAINT_WAIT_MS);

	let privAfter = '(gone)';
	try {
		const p2 = win.get_compositor_private();
		privAfter = p2 == null ? 'null' : contentState(p2);
	} catch (e) {
		privAfter = '(threw ' + formatError(e) + ')';
	}
	smokeLog('compositor-private-after-paint=' + privAfter);
	if (privAfter.indexOf('content=set') !== 0)
		throw new Error('miss paint (stand-in has no painted content)');

	const previews = findPreviews(globalObj.stage, 0, []);
	smokeLog('previews=' + previews.length
		+ previews.map(p => ' [' + p.title + ' ' + p.size + ']').join(''));
	if (previews.length === 0)
		throw new Error('miss preview (no WindowPreview under overview)');
	const sized = previews.filter(p => p.size !== '0x0' && p.size !== '?');
	if (sized.length === 0)
		throw new Error('miss preview-size (all previews 0x0)');

	smokeLog('ok');
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => runThumbnailProve(main));
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
