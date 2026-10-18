/**
 * Drop a window preview on another workspace thumbnail.
 *
 * Pass: `overview-drop-workspace-smoke: ok`
 * Fail: `overview-drop-workspace-smoke: miss <reason>`
 *
 *   GI_META_SMOKE=overview-drop-workspace-smoke \
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

const SMOKE = 'overview-drop-workspace-smoke';
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
 * @param {object} actor
 * @returns {string}
 */
function actorChain(actor) {
	const names = [];
	let current = actor;
	for (let i = 0; current != null && i < 6; i++) {
		let name = '?';
		try {
			if (current.name)
				name = String(current.name);
			else if (current.constructor != null)
				name = String(current.constructor.name);
		} catch (e) {
			name = '?';
		}
		names.push(name);
		current = current.get_parent ? current.get_parent() : null;
	}
	return names.join(' > ');
}

/**
 * @param {object} actor
 * @param {string} needle
 * @param {number} depth
 * @param {object[]} out
 * @returns {object[]}
 */
function findNamed(actor, needle, depth, out) {
	out = out || [];
	if (actor == null || depth > 16 || out.length > 40)
		return out;
	let name = '';
	try {
		name = actor.constructor != null ? String(actor.constructor.name) : '';
	} catch (e) {
		name = '';
	}
	if (name.indexOf(needle) >= 0)
		out.push(actor);
	let children = [];
	try {
		children = actor.get_children ? actor.get_children() : [];
	} catch (e) {
		children = [];
	}
	for (const child of children)
		findNamed(child, needle, depth + 1, out);
	return out;
}

/**
 * Record the chain from each {@code get_actor_at_pos}. Does not hide
 * actors. The compositor pick hook is what skips a hidden actor.
 *
 * @param {object} stage
 * @returns {{ lastPick: string }}
 */
function recordPicks(stage) {
	const state = { lastPick: '(none)' };
	const origAt = stage.get_actor_at_pos;
	stage.get_actor_at_pos = function (mode, x, y) {
		const actor = origAt.call(stage, mode, x, y);
		state.lastPick = actorChain(actor) + ' @' + x + ',' + y;
		return actor;
	};
	return state;
}

/**
 * Two stacked actors. The compositor hook should make the lower actor the hit.
 *
 * @param {object} globalObj
 */
async function probeHiddenFromPick(globalObj) {
	const stage = globalObj.stage;
	const bottom = new Clutter.Actor({
		name: 'pick-bottom',
		x: 80,
		y: 220,
		width: 120,
		height: 80,
		reactive: true,
	});
	const top = new Clutter.Actor({
		name: 'pick-top',
		x: 80,
		y: 220,
		width: 120,
		height: 80,
		reactive: true,
	});
	stage.add_child(bottom);
	stage.add_child(top);
	await delay(200);
	const [px, py] = top.get_transformed_position();
	const [pw, ph] = top.get_transformed_size();
	Shell.util_set_hidden_from_pick(top, true);
	const hit = stage.get_actor_at_pos(
		Clutter.PickMode.ALL, px + pw / 2, py + ph / 2);
	const hitName = hit != null && hit.name ? String(hit.name) : actorChain(hit);
	smokeLog('pick-hidden hit=' + hitName + ' at=' + (px + pw / 2) + ',' + (py + ph / 2));
	top.destroy();
	bottom.destroy();
}

/**
 * @param {object} main
 */
async function run(main) {
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	if (display == null)
		throw new Error('miss display');

	const pickState = recordPicks(globalObj.stage);
	await probeHiddenFromPick(globalObj);

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
		const list = display.list_all_windows();
		wins = (list != null ? list : []).filter(w =>
			w != null && w.window_type === Meta.WindowType.NORMAL);
		if (wins.length > 0)
			break;
		await delay(200);
	}
	if (wins.length === 0)
		throw new Error('miss window');
	const win = wins[wins.length - 1];
	const title = win.get_title();

	const wm = globalObj.workspace_manager;
	const home = win.get_workspace().index();
	for (let n = 0; wm.get_n_workspaces() > 2 && n < 20; n++) {
		const last = wm.get_n_workspaces() - 1;
		const index = last === home ? (home === 0 ? 1 : home - 1) : last;
		wm.remove_workspace(
			wm.get_workspace_by_index(index), globalObj.get_current_time());
	}
	if (wm.get_n_workspaces() < 2)
		wm.append_new_workspace(false, globalObj.get_current_time());
	smokeLog('n_workspaces=' + wm.get_n_workspaces());

	main.overview.show();
	const visDeadline = GLib.get_monotonic_time() + 8 * GLib.TIME_SPAN_SECOND;
	while (!main.overview.visible && GLib.get_monotonic_time() < visDeadline)
		await delay(100);
	if (!main.overview.visible)
		throw new Error('miss overview');
	await delay(800);

	const previews = findNamed(globalObj.stage, 'WindowPreview', 0, []);
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

	const here = win.get_workspace().index();
	let target = null;
	const thumbs = findNamed(globalObj.stage, 'WorkspaceThumbnail', 0, []);
	for (const thumb of thumbs) {
		let index = -1;
		try {
			index = thumb.metaWorkspace.index();
		} catch (e) {
			index = -1;
		}
		smokeLog('thumb index=' + index);
		if (target == null && index >= 0 && index !== here)
			target = thumb;
	}
	if (target == null)
		throw new Error('miss other-workspace-thumbnail');
	smokeLog('target index=' + target.metaWorkspace.index());
	for (const thumb of thumbs) {
		smokeLog('thumb-alloc index=' + thumb.metaWorkspace.index()
			+ ' x=' + thumb.x + ' y=' + thumb.y
			+ ' w=' + thumb.width + ' h=' + thumb.height);
		const internal = thumb.acceptDropInternal;
		if (internal == null || thumb._smokeWrapped)
			continue;
		thumb._smokeWrapped = true;
		thumb.acceptDropInternal = function (source, actor, time) {
			let mine = '?';
			try {
				const winActor = source.metaWindow.get_compositor_private();
				mine = String(this._isMyWindow(winActor));
			} catch (e) {
				mine = 'threw';
			}
			smokeLog('acceptDropInternal mine=' + mine
				+ ' ws=' + this.metaWorkspace.index());
			return internal.call(this, source, actor, time);
		};
	}
	const boxes = findNamed(globalObj.stage, 'ThumbnailsBox', 0, []);
	for (const box of boxes) {
		const accept = box.acceptDrop;
		if (accept == null || box._smokeWrapped)
			continue;
		box._smokeWrapped = true;
		box.acceptDrop = function (source, actor, x, y, time) {
			const ok = accept.call(this, source, actor, x, y, time);
			smokeLog('box-accept ok=' + ok
				+ ' dropWorkspace=' + this._dropWorkspace
				+ ' x=' + x + ' y=' + y);
			return ok;
		};
	}

	let moved = false;
	const proto = Object.getPrototypeOf(win);
	const origChange = proto.change_workspace_by_index;
	proto.change_workspace_by_index = function (index, append) {
		moved = true;
		smokeLog('change_workspace_by_index index=' + index);
		return origChange.call(this, index, append);
	};

	const [x, y] = preview.get_transformed_position();
	const [w, h] = preview.get_transformed_size();
	const cx = x + w / 2;
	const cy = y + h / 2;
	const [tx0, ty0] = target.get_transformed_position();
	const [tw, th] = target.get_transformed_size();
	let tx = tx0 + tw / 2;
	let ty = ty0 + th / 2;
	let foundThumb = false;
	for (let sy = 40; sy <= 160 && !foundThumb; sy += 20) {
		for (let sx = 80; sx <= 1100 && !foundThumb; sx += 40) {
			const hit = globalObj.stage.get_actor_at_pos(
				Clutter.PickMode.ALL, sx, sy);
			const chain = actorChain(hit);
			if (chain.indexOf('WorkspaceThumbnail') < 0)
				continue;
			tx = sx;
			ty = sy;
			foundThumb = true;
			smokeLog('sample ' + sx + ',' + sy + ' ' + chain);
		}
	}
	smokeLog('drag ' + cx + ',' + cy + ' -> thumb ' + tx + ',' + ty
		+ ' size=' + tw + 'x' + th);

	const seat = Clutter.get_default_backend().get_default_seat();
	const virt = seat.create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);
	const now = () => GLib.get_monotonic_time();
	virt.notify_absolute_motion(now(), cx, cy);
	await delay(50);
	virt.notify_button(now(), 1, Clutter.ButtonState.PRESSED);
	await delay(80);
	pickState.lastPick = '(pending)';
	let px = cx;
	let py = cy;
	for (let i = 1; i <= 12; i++) {
		if (pickState.lastPick.indexOf('@') < 0) {
			px = cx + (tx - cx) * Math.min(i, 8) / 8;
			py = cy + (ty - cy) * Math.min(i, 8) / 8;
		}
		virt.notify_absolute_motion(now(), px, py);
		await delay(120);
		smokeLog('step ' + i + ' ' + pickState.lastPick);
		if (pickState.lastPick.indexOf('WorkspaceThumbnail') >= 0)
			break;
		const at = /@([0-9.]+),([0-9.]+)/.exec(pickState.lastPick);
		if (at == null)
			continue;
		px += tx - parseFloat(at[1]);
		py += ty - parseFloat(at[2]);
	}
	await delay(200);
	virt.notify_button(now(), 1, Clutter.ButtonState.RELEASED);
	await delay(600);
	smokeLog('drop moved=' + moved + ' pick=' + pickState.lastPick);
	if (!moved)
		throw new Error('miss change_workspace_by_index pick=' + pickState.lastPick);
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
