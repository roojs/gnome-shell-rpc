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
imports.gi.versions.Clutter = '16';

const { Gio, GLib, Meta, Shell, Clutter } = imports.gi;

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
 * Walk the stage for overview workspaces (do they hold the window?) and
 * window previews (is the clone in the tree?).
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
		out.push({title: String(mw), size, actor});
		return out;
	}
	if (name === 'Workspace') {
		let n = '?';
		try {
			n = String(actor._windows != null ? actor._windows.length : '(no _windows)');
		} catch (e) {
			n = '(threw)';
		}
		out.push({title: 'Workspace _windows=' + n, size: '', ref: actor});
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
 * True when some actor under the preview holds content and is in the
 * stage tree. A Clutter.Clone of the offstage stand-in does not.
 * @param {object} actor
 * @param {number} depth
 * @returns {boolean}
 */
function descendantPaints(actor, depth) {
	if (actor == null || depth > 8)
		return false;
	try {
		if (actor.content != null && actor.has_allocation())
			return true;
	} catch (e) {
		/* keep walking */
	}
	let children = [];
	try {
		children = actor.get_children ? actor.get_children() : [];
	} catch (e) {
		children = [];
	}
	for (const child of children) {
		if (descendantPaints(child, depth + 1))
			return true;
	}
	return false;
}

/**
 * @param {string} cmd
 */
function procBaseName(cmd) {
	const tok = cmd.trim().split(/\s+/)[0];
	const slash = tok.lastIndexOf('/');
	return slash >= 0 ? tok.substring(slash + 1) : tok;
}

/** Harness: where did the child land? */
function logSpawnProbe(cmd) {
	const base = procBaseName(cmd);
	try {
		const [, out] = GLib.spawn_command_line_sync(
			'pgrep -a ' + base + ' 2>/dev/null || true');
		const text = out ? imports.byteArray.toString(out).trim() : '';
		smokeLog('proc ' + base + '=' + (text || '(none)'));
		if (!text)
			return;
		for (const line of text.split('\n')) {
			const pid = line.split(/\s+/)[0];
			const [, envOut] = GLib.spawn_command_line_sync(
				"tr '\\0' '\\n' </proc/" + pid + '/environ | grep -E ' +
				"'^(DISPLAY|WAYLAND_DISPLAY|GDK_BACKEND|DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR)=' || true");
			const envText = envOut ? imports.byteArray.toString(envOut).trim() : '';
			smokeLog('proc-env pid=' + pid + ' ' + (envText || '(none)').split('\n').join(' '));
		}
	} catch (e) {
		smokeLog('proc probe: ' + formatError(e));
	}
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
	// gsr-smoke itself is a Wayland client of mutter, so it carries
	// WAYLAND_SOCKET=<fd> for its own pre-connected socket. A Gio-spawned
	// grandchild inherits the NUMBER but not the fd, so its Wayland
	// handshake dies instantly (launch returns true, no process, no
	// window). The product launch path scrubs this; the smoke must too.
	ctx.unsetenv('WAYLAND_SOCKET');
	smokeLog('ctx: unset WAYLAND_SOCKET');
	if (typeof ctx.get_environment === 'function') {
		const env = ctx.get_environment();
		if (env != null) {
			for (const entry of env) {
				if (entry.startsWith('DISPLAY=')
					|| entry.startsWith('WAYLAND_DISPLAY=')
					|| entry.startsWith('WAYLAND_SOCKET=')
					|| entry.startsWith('GDK_BACKEND=')
					|| entry.startsWith('DBUS_SESSION_BUS_ADDRESS=')
					|| entry.startsWith('XDG_RUNTIME_DIR='))
					smokeLog('ctx-env ' + entry);
			}
		}
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
	if (wins.length === 0) {
		logSpawnProbe(CMD);
		throw new Error('miss window (no Meta NORMAL window after launch)');
	}

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

	// App-picker launch animation calls set_pivot_point(x, y) (iconGrid).
	// Probe the binding before the overview: a crash here (not a throw)
	// is the client SEGV seen by hand in the picker.
	let pivotType = '?';
	try {
		pivotType = typeof globalObj.stage.set_pivot_point;
	} catch (e) {
		pivotType = '(threw ' + formatError(e) + ')';
	}
	smokeLog('pivot-type=' + pivotType);
	try {
		globalObj.stage.set_pivot_point(0.5, 0.5);
		smokeLog('pivot-ok');
	} catch (e) {
		throw new Error('miss pivot (set_pivot_point threw '
			+ formatError(e) + ')');
	}
	// Same call on a fresh Clutter.Clone, mirroring iconGrid
	// zoomOutActorAtPos (the app-picker launch animation that crashed
	// the client by hand). A crash here is that SEGV, not a throw.
	let actorClone = null;
	try {
		actorClone = new Clutter.Clone({
			source: globalObj.stage,
			reactive: false,
		});
		smokeLog('clone-new=ok');
	} catch (e) {
		throw new Error('miss clone (Clutter.Clone construct threw '
			+ formatError(e) + ')');
	}
	let clonePivotType = '?';
	try {
		clonePivotType = typeof actorClone.set_pivot_point;
	} catch (e) {
		clonePivotType = '(threw ' + formatError(e) + ')';
	}
	smokeLog('clone-pivot-type=' + clonePivotType);
	try {
		actorClone.set_pivot_point(0.5, 0.5);
		smokeLog('clone-pivot-ok');
	} catch (e) {
		throw new Error('miss clone-pivot (set_pivot_point threw '
			+ formatError(e) + ')');
	}
	// Same call on an St widget, then the full stock launch-animation
	// path (iconGrid zoomOutActor: clone + pivot + uiGroup add + ease).
	// Either crashing is the hand-seen picker SEGV, not a throw.
	try {
		main.panel.set_pivot_point(0.5, 0.5);
		smokeLog('panel-pivot-ok');
	} catch (e) {
		throw new Error('miss panel-pivot (set_pivot_point threw '
			+ formatError(e) + ')');
	}
	try {
		const iconGrid = await import(
			'resource:///org/gnome/shell/ui/iconGrid.js');
		iconGrid.zoomOutActor(main.panel);
		smokeLog('zoom-out-ok');
	} catch (e) {
		throw new Error('miss zoom-out (zoomOutActor threw '
			+ formatError(e) + ')');
	}

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

	const foundEarly = findPreviews(globalObj.stage, 0, []);
	let painted = false;
	for (const row of foundEarly) {
		if (row.actor == null)
			continue;
		if (descendantPaints(row.actor, 0)) {
			painted = true;
			break;
		}
	}
	smokeLog('preview-paints=' + painted);
	if (!painted)
		throw new Error('miss paint-actor (overview preview has no allocated content)');

	const found = findPreviews(globalObj.stage, 0, []);
	const previews = found.filter(p => p.size !== '');
	smokeLog('found=' + found.length
 + found.map(p => ' [' + p.title + ' ' + p.size + ']').join(''));
	try {
		const actors = globalObj.get_window_actors();
		let hasGedit = false;
		let titles = '';
		try {
			titles = ' want=' + JSON.stringify(win.get_title());
		} catch (e) { /* keep scanning */ }
		for (const a of actors) {
			try {
				const t = a.meta_window != null
					? a.meta_window.get_title() : null;
				if (t === win.get_title()) {
					hasGedit = true;
					break;
				}
			} catch (e) { /* keep scanning */ }
		}
		smokeLog('window-actors=' + actors.length
			+ ' has-gedit=' + hasGedit + titles);
	} catch (e) {
		smokeLog('window-actors-threw ' + formatError(e));
	}
	if (previews.length === 0) {
		// Stock path left no preview.
		const wsMgr = globalObj.workspace_manager;
		const active = wsMgr.get_active_workspace();
		let located = '?';
		let monitor = '?';
		let skip = '?';
		let transient = '?';
		try {
			located = String(win.located_on_workspace(active));
		} catch (e) {
			located = '(threw ' + formatError(e) + ')';
		}
		try {
			monitor = String(win.get_monitor());
		} catch (e) {
			monitor = '(threw ' + formatError(e) + ')';
		}
		try {
			skip = String(win.skip_taskbar);
		} catch (e) {
			skip = '(threw ' + formatError(e) + ')';
		}
		try {
			transient = String(win.get_transient_for() != null);
		} catch (e) {
			transient = '(threw ' + formatError(e) + ')';
		}
		let stageKids = '?';
		try {
			stageKids = String(globalObj.stage.get_children().length);
		} catch (e) {
			stageKids = '(threw ' + formatError(e) + ')';
		}
		smokeLog('diag located=' + located + ' monitor=' + monitor
			+ ' skip_taskbar=' + skip + ' has_transient=' + transient
			+ ' stage-kids=' + stageKids
			+ ' overview-closing=' + main.overview.closing);
		throw new Error('miss preview (no WindowPreview under overview)');
	}
	const sized = previews.filter(p => p.size !== '0x0' && p.size !== '?');
	if (sized.length === 0)
		throw new Error('miss preview-size (all previews 0x0)');

	smokeLog('phase1-ok');
	// Phase 2: hand order — Workspace actors already exist (overview
	// stays shown), then a NEW window arrives. Constructor bulk-add
	// will not rerun; only window-added delivery can clone it.
	// Repro-side only. (No hide/show: re-showing wedges overview
	// re-layout in this tree; the delivery question needs none of it.)
	const ctx2 = globalObj.create_app_launch_context(0, -1);
	if (GLib.getenv('GI_WAYLAND_LAUNCH_UNSET_DISPLAY') === '1')
		ctx2.unsetenv('DISPLAY');
	ctx2.unsetenv('WAYLAND_SOCKET');
	const app2 = Gio.AppInfo.create_from_commandline(
		CMD, null, Gio.AppInfoCreateFlags.NONE);
	if (app2 === null)
		throw new Error('miss phase2 (create_from_commandline failed)');
	if (!app2.launch([], ctx2))
		throw new Error('miss phase2 (launch returned false)');
	const deadline2 = GLib.get_monotonic_time() + WAIT_MS * 1000;
	let wins2 = [];
	while (GLib.get_monotonic_time() < deadline2) {
		wins2 = normalWindows(display);
		if (wins2.length >= 2)
			break;
		await delay(200);
	}
	smokeLog('phase2 windows-normal=' + wins2.length);
	if (wins2.length < 2)
		throw new Error('miss phase2 (second window never appeared)');
	let newWin = null;
	let newTitle = '?';
	for (const w of wins2) {
		let t = '?';
		try {
			t = w.get_title();
		} catch (e) { /* keep scanning */ }
		if (t !== title) {
			newWin = w;
			newTitle = t;
			break;
		}
	}
	if (newWin == null)
		throw new Error('miss phase2 (no window distinct from first)');
	smokeLog('phase2 new-window title=' + JSON.stringify(newTitle));
	try {
		newWin.get_compositor_private();
	} catch (e) {
		throw new Error('miss phase2 (stand-in threw '
			+ formatError(e) + ')');
	}
	await delay(PAINT_WAIT_MS);
	const found2 = findPreviews(globalObj.stage, 0, []);
	const previews2 = found2.filter(p => p.size !== '');
	smokeLog('phase2 found=' + found2.length
		+ found2.map(p => ' [' + p.title + ' ' + p.size + ']').join(''));
	const sized2 = previews2.filter(
		p => p.size !== '0x0' && p.size !== '?');
	if (!sized2.some(p => p.title === newTitle))
		throw new Error('miss phase2-preview (late window never cloned)');

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
