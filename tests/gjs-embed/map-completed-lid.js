/**
 * Stock WindowManager._mapWindow calls Shell.WM.completed_map on every
 * map. The plugin on that object is a stand-in with no lease. The
 * server already completed the map, so this call must not RPC.
 *
 * Pass: `map-completed-lid: ok`
 * Fail: `map-completed-lid: miss …`
 *
 *   GI_META_SMOKE=map-completed-lid ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { GLib, Shell } = imports.gi;

const SMOKE = 'map-completed-lid';
const WAIT_MS = parseInt(GLib.getenv('GI_META_SMOKE_WAIT_MS') || '8000', 10);

function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function main() {
	const globalObj = Shell.Global.get();
	const wm = globalObj.window_manager;
	if (wm == null)
		throw new Error('window_manager is null');

	let done = false;
	wm.connect('map', (_wm, actor) => {
		if (done)
			return;
		done = true;
		wm.completed_map(actor);
		smokeLog('ok');
	});

	const app = Shell.AppSystem.get_default().lookup_app(
		'org.gtk.Demo4.desktop');
	if (app == null) {
		smokeLog('miss no-app');
		return;
	}
	try {
		app.launch(0, -1, 0);
	} catch (e) {
		smokeLog('miss launch ' + e);
		return;
	}

	const display = globalObj.get_display();
	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	const ctx = GLib.MainContext.default();
	while (!done && GLib.get_monotonic_time() < deadline) {
		/* An RPC reads queued notifications. usleep alone does not. */
		display.list_all_windows();
		while (ctx.pending())
			ctx.iteration(false);
		if (!done)
			GLib.usleep(50 * 1000);
	}
	if (!done)
		smokeLog('miss map-not-emitted');
}

main();
