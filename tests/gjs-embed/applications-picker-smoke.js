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
}

function delay(ms) {
	return new Promise(resolve => {
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
			resolve();
			return GLib.SOURCE_REMOVE;
		});
	});
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

	await delay(1000);
	const [x, y] = button.get_transformed_position();
	const [width, height] = button.get_transformed_size();
	const clickX = x + width / 2;
	const clickY = y + height / 2;
	smokeLog('click at=' + clickX + ',' + clickY
		+ ' size=' + width + 'x' + height
		+ ' before=' + stateAdjustment.value);
	globalObj.pointer_click(clickX, clickY);
	await delay(4000);

	const layout = appDisplay._grid?.layout_manager;
	const ids = countPickableApps(stage);
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
