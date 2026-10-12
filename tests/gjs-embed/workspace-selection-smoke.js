/**
 * Click a non-active workspace thumbnail through the real pointer path.
 *
 * Pass: `workspace-selection-smoke: ok`
 * Fail: `workspace-selection-smoke: miss <reason>`
 *
 *   GI_META_SMOKE=workspace-selection-smoke GSR_WESTON_PIXMAN=1 \
 *   GSR_NESTED_TIMEOUT=60 ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Clutter = '16';
imports.gi.versions.GLib = '2.0';
imports.gi.versions.Shell = '16';

const {GLib, Shell} = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';

const SMOKE = 'workspace-selection-smoke';

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

function findThumbnailsBox(actor) {
	if (Array.isArray(actor?._thumbnails) &&
			typeof actor?._activateThumbnailAtPoint === 'function')
		return actor;
	for (const child of actor?.get_children?.() ?? []) {
		const found = findThumbnailsBox(child);
		if (found != null)
			return found;
	}
	return null;
}

async function run() {
	const main = await import('resource:///org/gnome/shell/ui/main.js');
	await main.start();

	const globalObj = Shell.Global.get();
	main.overview.show();
	const deadline = GLib.get_monotonic_time() + 10 * GLib.TIME_SPAN_SECOND;
	let box = null;
	while (GLib.get_monotonic_time() < deadline) {
		box = findThumbnailsBox(globalObj.stage);
		if (box?._thumbnails?.length > 1)
			break;
		await delay(200);
	}
	if (box == null || box._thumbnails.length < 2) {
		smokeLog('miss thumbnails=' + (box?._thumbnails?.length ?? 0));
		globalObj.context.terminate();
		return;
	}

	const before = globalObj.workspace_manager.get_active_workspace_index();
	const target = box._thumbnails.find(
		thumbnail => thumbnail.metaWorkspace.index() !== before);
	if (target == null) {
		smokeLog('miss no-inactive-thumbnail');
		globalObj.context.terminate();
		return;
	}

	const [x, y] = target.get_transformed_position();
	const [width, height] = target.get_transformed_size();
	const clickX = x + width / 2;
	const clickY = y + height / 2;
	smokeLog('click before=' + before
		+ ' target=' + target.metaWorkspace.index()
		+ ' at=' + clickX + ',' + clickY
		+ ' size=' + width + 'x' + height);
	globalObj.pointer_click(clickX, clickY);
	await delay(1200);

	const after = globalObj.workspace_manager.get_active_workspace_index();
	smokeLog('after=' + after + ' overview=' + main.overview.visible);
	if (after === target.metaWorkspace.index())
		smokeLog('ok');
	else
		smokeLog('miss active=' + after);
	globalObj.context.terminate();
}

imports._promiseNative.setMainLoopHook(() => {
	run().catch(e => {
		smokeLog('miss exception ' + e);
		Shell.Global.get().context.terminate();
	});
	Shell.Global.get().context.run_main_loop();
});
