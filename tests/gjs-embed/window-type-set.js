/**
 * Desktop Icons calls set_type(DESKTOP). The client property is
 * read-only, so the notify that follows is rejected and the shell
 * keeps treating the window as a normal window.
 *
 * Pass: `window-type-set: ok`
 * Fail: `window-type-set: miss …`
 *
 *   GI_META_SMOKE=window-type-set ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { GLib, Meta, Shell } = imports.gi;

const SMOKE = 'window-type-set';
const WAIT_MS = parseInt(GLib.getenv('GI_META_SMOKE_WAIT_MS') || '12000', 10);

function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function main() {
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	const wm = globalObj.window_manager;
	if (wm == null)
		throw new Error('window_manager is null');

	let done = false;
	wm.connect('map', (_wm, actor) => {
		if (done)
			return;
		const window = actor.meta_window ?? actor.get_meta_window?.();
		if (window == null)
			return;
		done = true;
		let notified = false;
		window.connect('notify::window-type', () => {
			notified = true;
		});
		try {
			window.window_type = Meta.WindowType.DESKTOP;
		} catch (e) {
			const msg = e != null && e.message != null ? e.message : String(e);
			smokeLog('miss ' + msg);
			return;
		}
		const type = window.get_window_type != null
			? window.get_window_type()
			: window.window_type;
		smokeLog('type=' + type + ' notified=' + notified);
		if (type !== Meta.WindowType.DESKTOP || !notified)
			smokeLog('miss type=' + type + ' notified=' + notified);
		else
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

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	const ctx = GLib.MainContext.default();
	while (!done && GLib.get_monotonic_time() < deadline) {
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
