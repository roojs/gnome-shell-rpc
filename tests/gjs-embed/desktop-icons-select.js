/**
 * Desktop Icons only lowers its window from Shell.WM::map. If a new
 * window shows up and that signal does not fire, the window stays
 * above the session and clicks draw a selection rectangle.
 *
 * Pass: `desktop-icons-select: ok`
 * Fail: `desktop-icons-select: miss map-not-emitted`
 *
 *   GI_META_SMOKE=desktop-icons-select ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { GLib, Meta, Shell } = imports.gi;

const SMOKE = 'desktop-icons-select';
const CMD = GLib.getenv('GI_META_SMOKE_CMD') || 'gtk4-demo';
const WAIT_MS = parseInt(GLib.getenv('GI_META_SMOKE_WAIT_MS') || '8000', 10);

function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function listWindows(display) {
	if (typeof display.list_all_windows === 'function') {
		const list = display.list_all_windows();
		return list != null ? list : [];
	}
	const focus = display.get_focus_window();
	return focus != null ? [focus] : [];
}

function windowType(w) {
	if (w == null)
		return null;
	if (typeof w.get_window_type === 'function')
		return w.get_window_type();
	return w.window_type;
}

function countNormalWindows(display) {
	let n = 0;
	for (const w of listWindows(display)) {
		if (w != null && windowType(w) === Meta.WindowType.NORMAL)
			n++;
	}
	return n;
}

function main() {
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	const wm = globalObj.window_manager;
	if (wm == null)
		throw new Error('window_manager is null');

	let maps = 0;
	let lowered = false;
	wm.connect_after('map', (_wm, actor) => {
		maps += 1;
		smokeLog('map maps=' + maps);
		const window = actor?.meta_window ?? actor?.get_meta_window?.();
		if (window == null || window.lower == null) {
			smokeLog('lower missing');
			return;
		}
		try {
			window.lower();
			lowered = true;
			smokeLog('lower ok');
		} catch (e) {
			smokeLog('lower ' + e);
		}
	});

	const baseline = countNormalWindows(display);
	smokeLog('windows-normal baseline=' + baseline);
	const app = Shell.AppSystem.get_default().lookup_app(
		'org.gtk.Demo4.desktop');
	if (app == null) {
		smokeLog('miss no-app');
		return;
	}
	let launched = false;
	try {
		launched = app.launch(0, -1, 0);
	} catch (e) {
		smokeLog('miss launch ' + e);
		return;
	}
	smokeLog('launch returned ' + launched);

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	let normal = baseline;
	while (GLib.get_monotonic_time() < deadline) {
		normal = countNormalWindows(display);
		if (normal > baseline && maps > 0)
			break;
		GLib.usleep(200 * 1000);
	}

	smokeLog('windows-normal after=' + normal + ' maps=' + maps);
	if (normal <= baseline) {
		smokeLog('miss no-window');
		return;
	}
	if (maps === 0) {
		smokeLog('miss map-not-emitted');
		return;
	}
	if (!lowered) {
		smokeLog('miss lower');
		return;
	}
	smokeLog('ok');
}

main();
