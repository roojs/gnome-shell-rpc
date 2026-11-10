/**
 * Stock Shell.App leaves the dash when every window is skip-taskbar.
 * Desktop Icons hides its gjs window that way. This shell keeps the
 * app RUNNING, so the footer still shows the process name.
 *
 * Pass: `gjs-app-skip: ok`
 * Fail: `gjs-app-skip: miss …`
 *
 *   GI_META_SMOKE=gjs-app-skip ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { GLib, Shell } = imports.gi;

const SMOKE = 'gjs-app-skip';
const WAIT_MS = parseInt(GLib.getenv('GI_META_SMOKE_WAIT_MS') || '12000', 10);

function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function runningHas(app) {
	const running = Shell.AppSystem.get_default().get_running();
	if (running == null)
		return false;
	for (let i = 0; i < running.length; i++) {
		if (running[i] === app)
			return true;
	}
	return false;
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
		const tracker = Shell.WindowTracker.get_default();
		const app = tracker.get_window_app(window);
		if (app == null) {
			smokeLog('miss no-app');
			return;
		}
		const before = app.state;
		const name = app.get_name();
		try {
			window.skip_taskbar = true;
		} catch (e) {
			const msg = e != null && e.message != null ? e.message : String(e);
			smokeLog('miss ' + msg);
			return;
		}
		const after = app.state;
		const listed = runningHas(app);
		smokeLog('name=' + name + ' before=' + before + ' after=' + after
			+ ' listed=' + listed + ' skip=' + window.skip_taskbar);
		if (after !== Shell.AppState.STOPPED || listed)
			smokeLog('miss name=' + name + ' after=' + after + ' listed=' + listed);
		else
			smokeLog('ok');
	});

	const appInfo = Shell.AppSystem.get_default().lookup_app(
		'org.gtk.Demo4.desktop');
	if (appInfo == null) {
		smokeLog('miss no-app');
		return;
	}
	try {
		appInfo.launch(0, -1, 0);
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
