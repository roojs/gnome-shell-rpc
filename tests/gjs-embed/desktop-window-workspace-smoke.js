/**
 * Move a mapped window to another workspace on the regular desktop
 * (overview hidden). Stock does that from a mutter move grab plus
 * change_workspace, not from St.DndStartGesture.
 *
 * Pass: `desktop-window-workspace-smoke: ok`
 * Fail: `desktop-window-workspace-smoke: miss <reason>`
 *
 *   GI_META_SMOKE=desktop-window-workspace-smoke \
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

const SMOKE = 'desktop-window-workspace-smoke';
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
 * @param {object} main
 * @param {boolean} visible
 * @param {number} ms
 */
async function waitOverview(main, visible, ms) {
	if (main.overview.visible !== visible) {
		if (visible)
			main.overview.show();
		else
			main.overview.hide();
	}
	const deadline = GLib.get_monotonic_time() + ms * GLib.TIME_SPAN_MILLISECOND;
	while (main.overview.visible !== visible
			&& GLib.get_monotonic_time() < deadline)
		await delay(100);
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
 * @param {object[]} previews
 * @returns {string}
 */
function previewPos(previews) {
	const bits = [];
	for (let i = 0; i < previews.length; i++) {
		const p = previews[i];
		const [x, y] = p.get_transformed_position();
		bits.push(Math.round(x) + ',' + Math.round(y));
	}
	return bits.join(' ');
}

/**
 * @param {object} main
 */
async function run(main) {
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	if (display == null)
		throw new Error('miss display');

	const layout = main.layoutManager;
	smokeLog('startingUp=' + layout._startingUp);
	const startDeadline = GLib.get_monotonic_time() + 8000 * 1000;
	while (layout._startingUp && GLib.get_monotonic_time() < startDeadline)
		await delay(100);
	if (layout._startingUp)
		throw new Error('miss startup still starting');
	smokeLog('startup-complete cover=' + (layout._coverPane ? 'yes' : 'no'));

	const ctx = globalObj.create_app_launch_context(0, -1);
	if (GLib.getenv('GI_WAYLAND_LAUNCH_UNSET_DISPLAY') === '1')
		ctx.unsetenv('DISPLAY');
	ctx.unsetenv('WAYLAND_SOCKET');
	ctx.setenv('WAYLAND_DEBUG', '1');
	const app = Gio.AppInfo.create_from_commandline(
		CMD, null, Gio.AppInfoCreateFlags.NONE);
	if (app === null || !app.launch([], ctx))
		throw new Error('miss launch');
	await delay(400);
	if (!app.launch([], ctx))
		throw new Error('miss launch2');

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	let wins = [];
	while (GLib.get_monotonic_time() < deadline) {
		const list = display.list_all_windows();
		wins = (list != null ? list : []).filter(w =>
			w != null && w.window_type === Meta.WindowType.NORMAL);
		if (wins.length >= 2)
			break;
		await delay(200);
	}
	if (wins.length === 0)
		throw new Error('miss window');
	const win = wins[wins.length - 1];

	const manager = globalObj.workspace_manager;
	if (manager.n_workspaces < 2)
		manager.append_new_workspace(false, globalObj.get_current_time());
	if (manager.n_workspaces < 2)
		throw new Error('miss workspaces (still ' + manager.n_workspaces + ')');

	await waitOverview(main, true, 8000);
	if (!main.overview.visible)
		throw new Error('miss overview after launch');
	await delay(400);
	let previews = findPreviews(globalObj.stage, 0, []);
	const previewSamples = [];
	for (let i = 0; i < 8; i++) {
		previewSamples.push(previewPos(previews));
		await delay(80);
	}
	smokeLog('previews=' + previews.length
		+ ' wins=' + wins.length
		+ ' samples=' + previewSamples.join(' | '));
	if (new Set(previewSamples).size > 1)
		throw new Error('miss preview-vibrate samples differ');

	if (previews.length > 0) {
		const [px, py] = previews[0].get_transformed_position();
		const [pw, ph] = previews[0].get_transformed_size();
		globalObj.pointer_click(px + pw / 2, py + ph / 2);
		await delay(400);
		previews = findPreviews(globalObj.stage, 0, []);
		const afterClick = [];
		for (let i = 0; i < 8; i++) {
			afterClick.push(previewPos(previews));
			await delay(80);
		}
		smokeLog('after-click samples=' + afterClick.join(' | '));
		if (new Set(afterClick).size > 1)
			throw new Error('miss preview-vibrate after click');
	}

	await waitOverview(main, false, 8000);
	if (main.overview.visible)
		throw new Error('miss desktop after launch (overview visible)');

	for (let i = 0; i < wins.length; i++) {
		if (wins[i].maximized_horizontally || wins[i].maximized_vertically) {
			wins[i].unmaximize(Meta.MaximizeFlags.BOTH);
			await delay(200);
		}
	}
	if (win.maximized_horizontally || win.maximized_vertically)
		throw new Error('miss still-maximized');
	wins[0].move_resize_frame(true, 20, 80, 300, 220);
	if (wins.length > 1)
		wins[1].move_resize_frame(true, 360, 80, 300, 220);
	await delay(200);
	win.raise();
	win.activate(globalObj.get_current_time());
	await delay(100);

	const samples = [];
	for (let i = 0; i < 8; i++) {
		const r = win.get_frame_rect();
		samples.push(r.x + ',' + r.y);
		await delay(80);
	}
	const home = win.get_workspace().index();
	let rect = win.get_frame_rect();
	const otherBits = [];
	for (let i = 0; i < wins.length; i++) {
		const r = wins[i].get_frame_rect();
		otherBits.push(wins[i].get_title() + '=' + r.x + ',' + r.y
			+ ' ' + r.width + 'x' + r.height);
	}
	smokeLog('home=' + home
		+ ' n=' + manager.n_workspaces
		+ ' overview=' + main.overview.visible
		+ ' frame=' + rect.x + ',' + rect.y
		+ ' ' + rect.width + 'x' + rect.height
		+ ' maxh=' + win.maximized_horizontally
		+ ' maxv=' + win.maximized_vertically
		+ ' samples=' + samples.join(' ')
		+ ' all=' + otherBits.join(' ; '));
	if (new Set(samples).size > 1)
		smokeLog('vibrate samples differ');

	win.move_frame(true, rect.x + 40, rect.y);
	await delay(200);
	const placed = win.get_frame_rect();
	smokeLog('placed=' + placed.x + ',' + placed.y);
	if (Math.abs(placed.x - (rect.x + 40)) > 40)
		throw new Error('miss move_frame to=' + placed.x + ',' + placed.y
			+ ' want=' + (rect.x + 40) + ',' + rect.y);
	rect = placed;

	const seat = Clutter.get_default_backend().get_default_seat();
	const virt = seat.create_virtual_device(
		Clutter.InputDeviceType.POINTER_DEVICE);
	const sx = rect.x + 80;
	const sy = rect.y + 16;
	const ex = sx + 200;
	const pick = globalObj.stage.get_actor_at_pos(
		Clutter.PickMode.REACTIVE, sx, sy);
	const chain = [];
	let walk = pick;
	while (walk != null && chain.length < 8) {
		chain.push(walk.toString()
			+ ':' + (walk.get_name() ? walk.get_name() : '')
			+ ' ' + Math.round(walk.x) + ',' + Math.round(walk.y)
			+ ' ' + Math.round(walk.width) + 'x'
			+ Math.round(walk.height));
		walk = walk.get_parent();
	}
	const actors = globalObj.get_window_group().get_children();
	const actorBits = [];
	for (let i = 0; i < actors.length; i++) {
		const a = actors[i];
		const mw = a.meta_window;
		actorBits.push((a.toString())
			+ ' r=' + a.reactive
			+ ' vis=' + a.visible
			+ ' ' + Math.round(a.x) + ',' + Math.round(a.y)
			+ ' ' + Math.round(a.width) + 'x' + Math.round(a.height)
			+ (mw ? ' title=' + mw.get_title() : ''));
	}
	const actor = win.get_compositor_private();
	const kids = [];
	if (actor != null) {
		const ch = actor.get_children();
		for (let i = 0; i < (ch != null ? ch.length : 0); i++) {
			const c = ch[i];
			kids.push((c.constructor ? c.constructor.name : '?')
				+ ' r=' + c.reactive
				+ ' ' + Math.round(c.x) + ',' + Math.round(c.y)
				+ ' ' + Math.round(c.width) + 'x'
				+ Math.round(c.height));
		}
	}
	smokeLog('press=' + sx + ',' + sy + ' drag=' + ex + ',' + sy
		+ ' maxh=' + win.maximized_horizontally
		+ ' maxv=' + win.maximized_vertically
		+ ' pick-ctor=' + (pick && pick.constructor ? pick.constructor.name : '')
		+ ' pick-r=' + (pick ? pick.reactive : '')
		+ ' pick-chain=' + chain.join(' | ')
		+ ' kids=' + kids.join(' ; ')
		+ ' window-actors=' + actorBits.join(' ; '));
	const captured = [];
	const capId = globalObj.stage.connect('captured-event', (actor, event) => {
		captured.push(String(event.type()));
		return Clutter.EVENT_PROPAGATE;
	});
	const now = () => GLib.get_monotonic_time();
	virt.notify_absolute_motion(now(), sx, sy);
	await delay(50);
	virt.notify_button(now(), 1, Clutter.ButtonState.PRESSED);
	await delay(80);
	const focus = display.get_focus_window();
	let evActor = '';
	try {
		const ev = Clutter.get_current_event();
		const ea = ev != null ? globalObj.stage.get_event_actor(ev) : null;
		evActor = ea == null ? 'null'
			: ((ea.constructor ? ea.constructor.name : '?')
				+ ' ' + ea.toString());
	} catch (e) {
		evActor = 'threw ' + formatError(e);
	}
	smokeLog('pressed focus=' + (focus == null ? 'null' : focus.get_title())
		+ ' same=' + (focus === win)
		+ ' grabbed=' + display.is_grabbed()
		+ ' allows_move=' + win.allows_move()
		+ ' captured=' + captured.join(',')
		+ ' ev-actor=' + evActor);
	for (let i = 1; i <= 10; i++) {
		virt.notify_absolute_motion(now(), sx + (ex - sx) * i / 10, sy);
		await delay(80);
	}
	virt.notify_absolute_motion(now(), ex, sy);
	await delay(400);
	virt.notify_button(now(), 1, Clutter.ButtonState.RELEASED);
	await delay(400);
	globalObj.stage.disconnect(capId);

	const moved = win.get_frame_rect();
	const after = win.get_workspace().index();
	const active = manager.get_active_workspace_index();
	const afterBits = [];
	for (let i = 0; i < wins.length; i++) {
		const r = wins[i].get_frame_rect();
		afterBits.push(wins[i].get_title() + '=' + r.x + ',' + r.y);
	}
	smokeLog('moved=' + moved.x + ',' + moved.y
		+ ' after=' + after + ' active=' + active
		+ ' all=' + afterBits.join(' ; '));
	if (Math.abs(moved.x - rect.x) < 80)
		throw new Error('miss titlebar-move dx='
			+ (moved.x - rect.x) + ' from='
			+ rect.x + ',' + rect.y + ' to='
			+ moved.x + ',' + moved.y);
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
