/**
 * Open Show Applications through the real pointer path and require a usable grid.
 *
 * This deliberately does not prime IconGridLayout or force the overview state.
 *
 * Pass: `applications-picker-smoke: ok`
 * Fail: `applications-picker-smoke: miss <reason>`
 *
 *   GI_META_SMOKE=applications-picker-smoke GSR_WESTON_PIXMAN=1 \
 *   GSR_NESTED_TIMEOUT=60 ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Clutter = '16';
imports.gi.versions.GLib = '2.0';
imports.gi.versions.Shell = '16';

const {Clutter, GLib, Shell} = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';

const SMOKE = 'applications-picker-smoke';

function smokeLog(message) {
	log(SMOKE + ': ' + message);
	log('shell-boot/ui/init: ' + message);
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
	for (let current = actor;
		current != null && parts.length < 8;
		current = current.get_parent?.() ?? null) {
		const type = current.constructor?.name ?? 'actor';
		const name = current.name ? '#' + current.name : '';
		const style = current.style_class ? '.' + current.style_class : '';
		parts.push(type + name + style);
	}
	return parts.join(' > ');
}

function actorBox(actor) {
	const [cacheW, cacheH] = actor.allocation.get_size();
	let server = 'err';
	let width = 'err';
	try {
		const b = actor.get_allocation_box();
		const [sw, sh] = b.get_size();
		server = b.x1 + ',' + b.y1 + ' ' + sw + 'x' + sh;
	} catch (e) {
		server = 'err';
	}
	try {
		width = actor.get_width() + 'x' + actor.get_height();
	} catch (e) {
		width = 'err';
	}
	return 'cache=' + cacheW + 'x' + cacheH
		+ ' server=' + server
		+ ' wh=' + width
		+ ' expand=' + actor.x_expand + ',' + actor.y_expand
		+ ' align=' + actor.x_align + ',' + actor.y_align
		+ ' visible=' + actor.visible
		+ ' mapped=' + actor.mapped
		+ ' children=' + actor.get_n_children();
}

function appIconForActor(actor) {
	for (let current = actor; current != null; current = current.get_parent?.() ?? null) {
		if (current.app?.get_id != null)
			return current;
	}
	return null;
}

function countPickableApps(stage) {
	const ids = new Set();
	for (let y = 80; y < stage.height - 40; y += 50) {
		for (let x = 40; x < stage.width - 40; x += 50) {
			const actor = stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, x, y);
			const icon = appIconForActor(actor);
			if (icon != null)
				ids.add(icon.app.get_id());
		}
	}
	return ids;
}

async function run() {
	const main = await import('resource:///org/gnome/shell/ui/main.js');
	await main.start();

	const globalObj = Shell.Global.get();
	const stage = globalObj.stage;
	main.overview.show();
	const button = main.overview.dash?.showAppsButton;
	const appDisplay = main.overview._overview?.controls?.appDisplay;
	const stateAdjustment = main.overview._overview?.controls?._stateAdjustment;
	if (button == null || appDisplay == null || stateAdjustment == null) {
		smokeLog('miss controls');
		globalObj.context.terminate();
		return;
	}

	let x = 0;
	let y = 0;
	let width = 0;
	let height = 0;
	let lastBox = '';
	let stable = 0;
	for (let i = 0; i < 15 && stable < 2; i++) {
		await delay(200);
		const [nx, ny] = button.get_transformed_position();
		const [nw, nh] = button.get_transformed_size();
		const box = nx + ',' + ny + ' ' + nw + 'x' + nh;
		stable = box === lastBox && nw > 0 && nh > 0 ? stable + 1 : 0;
		lastBox = box;
		x = nx;
		y = ny;
		width = nw;
		height = nh;
	}
	const clickX = x + width / 2;
	const clickY = y + height / 2;
	const picked = stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, clickX, clickY);
	// Virtual absolute motion lands 38px left and 59px above the stage
	// point (X event 530,501 for a request of 568,560, then 568,560 for
	// a request of 606,619). Aim so the event hits this button.
	const eventX = clickX + 38;
	const eventY = clickY + 59;
	const eventPick = stage.get_actor_at_pos(Clutter.PickMode.REACTIVE, clickX - 38, clickY - 59);
	smokeLog('click at=' + clickX + ',' + clickY
		+ ' size=' + width + 'x' + height
		+ ' stable=' + stable
		+ ' before=' + stateAdjustment.value
		+ ' pick=' + actorChain(picked)
		+ ' event-space=' + actorChain(eventPick)
		+ ' aim=' + eventX + ',' + eventY);
	globalObj.pointer_click(eventX, eventY);
	await delay(800);
	if (!button.checked) {
		const [rx, ry] = button.get_transformed_position();
		const [rw, rh] = button.get_transformed_size();
		const retryX = rx + rw / 2 + 38;
		const retryY = ry + rh / 2 + 59;
		smokeLog('retry aim=' + retryX + ',' + retryY
			+ ' size=' + rw + 'x' + rh);
		globalObj.pointer_click(retryX, retryY);
		await delay(800);
	}
	await delay(2500);

	const layout = appDisplay._grid?.layout_manager;
	const ids = countPickableApps(stage);
	const scroll = appDisplay._scrollView;
	const scrollParent = scroll.get_parent();
	const box = appDisplay._box;
	const appLayout = appDisplay.layout_manager;
	smokeLog('boxes app=' + actorBox(appDisplay)
		+ ' appLayout=' + (appLayout ? appLayout.constructor.name : 'null')
		+ ' box=' + actorBox(box)
		+ ' scrollParent=' + actorBox(scrollParent)
		+ ' ' + scrollParent.layout_manager.constructor.name
		+ ' scroll=' + actorBox(scroll)
		+ ' grid=' + actorBox(appDisplay._grid));
	function preferred(actor) {
		try {
			const [minW, minH, natW, natH] = actor.get_preferred_size();
			return minW + '/' + natW + 'x' + minH + '/' + natH;
		} catch (e) {
			return 'err';
		}
	}
	smokeLog('pref app=' + preferred(appDisplay)
		+ ' box=' + preferred(box)
		+ ' scrollParent=' + preferred(scrollParent)
		+ ' scroll=' + preferred(scroll)
		+ ' grid=' + preferred(appDisplay._grid));
	smokeLog('state=' + stateAdjustment.value
		+ ' checked=' + button.checked
		+ ' visible=' + appDisplay.visible
		+ ' mapped=' + appDisplay.mapped
		+ ' items=' + (appDisplay._orderedItems?.length ?? -1)
		+ ' page=' + (layout?._pageWidth ?? -1) + 'x' + (layout?._pageHeight ?? -1)
		+ ' pickable=' + ids.size);

	if (!button.checked || stateAdjustment.value < 1.9)
		smokeLog('miss state');
	else if (!appDisplay.visible || !appDisplay.mapped)
		smokeLog('miss display');
	else if ((appDisplay._orderedItems?.length ?? 0) === 0)
		smokeLog('miss items');
	else if ((layout?._pageWidth ?? 0) <= 0 || (layout?._pageHeight ?? 0) <= 0)
		smokeLog('miss page-size');
	else if (ids.size === 0)
		smokeLog('miss pickable-icons');
	else
		smokeLog('ok');
	globalObj.context.terminate();
}

imports._promiseNative.setMainLoopHook(() => {
	run().catch(e => {
		smokeLog('miss exception ' + e);
		Shell.Global.get().context.terminate();
	});
	Shell.Global.get().context.run_main_loop();
});
