/**
 * 0.5 Meta vertical slice — nested mutter only.
 *
 * LAUNCH via stock Meta launch path + Gio:
 *   display.get_startup_notification().create_launcher()
 *   Gio.AppInfo.launch([], launcher)
 * FETCH window; optional minimize → hold → unminimize.
 *
 * Default app: gtk4-demo. Override: GI_META_SMOKE_CMD='gtk4-demo'
 * Minimize + unminimize cycle: GI_META_SMOKE_MINIMIZE=1
 * Hold (ms) before minimize and before unminimize: GI_META_SMOKE_HOLD_MS (default 5000)
 *
 * Progress uses GJS {@link log} (domain prefix meta-smoke) so gjs-embed --debug
 * writes to ~/.cache/gnome-shell-rpc/org.gnome.ShellRpc.GjsEmbed.debug.log
 */

imports.gi.versions.Meta = '16';

const { Gio, GLib, Meta } = imports.gi;

const SMOKE_DOMAIN = 'meta-smoke';
const APP_CMD = GLib.getenv('GI_META_SMOKE_CMD') || 'gtk4-demo';
const WAIT_MS = 8000;
const POLL_MS = 200;
const DEFAULT_HOLD_MS = 5000;

/**
 * @returns {number}
 */
function holdMsBeforeMinimize() {
	const raw = GLib.getenv('GI_META_SMOKE_HOLD_MS');
	if (raw !== null && raw.length > 0) {
		return parseInt(raw, 10);
	}
	return DEFAULT_HOLD_MS;
}

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * @returns {Meta.Display}
 */
function getDisplay() {
	if (typeof Meta.get_display === 'function') {
		return Meta.get_display();
	}
	throw new Error(
		'Meta.get_display() missing — stub bootstrap not wired yet'
	);
}

/**
 * Launch {@link APP_CMD} with Meta.LaunchContext (GAppLaunchContext).
 *
 * @param {Meta.Display} display
 */
function launchApp(display) {
	const startup = display.get_startup_notification();
	const launcher = startup.create_launcher();
	const app = Gio.AppInfo.create_from_commandline(
		APP_CMD,
		null,
		Gio.AppInfoCreateFlags.NONE
	);
	if (app === null) {
		throw new Error('AppInfo.create_from_commandline failed: ' + APP_CMD);
	}
	const ok = app.launch([], launcher);
	if (!ok) {
		throw new Error('AppInfo.launch failed: ' + APP_CMD);
	}
	smokeLog('launch: ' + APP_CMD);
}

/**
 * @param {Meta.Display} display
 * @returns {Meta.Window[]}
 */
function listWindows(display) {
	if (typeof display.list_all_windows === 'function') {
		const list = display.list_all_windows();
		return list !== null ? list : [];
	}
	const focus = display.get_focus_window();
	return focus !== null ? [focus] : [];
}

/**
 * @param {Meta.Display} display
 * @returns {Meta.Window|null}
 */
function findTargetWindow(display) {
	const focus = display.get_focus_window();
	if (focus !== null) {
		return focus;
	}
	const windows = listWindows(display);
	for (let i = 0; i < windows.length; i++) {
		const win = windows[i];
		if (win === null) {
			continue;
		}
		try {
			const title = win.get_title();
			if (title !== null && title.length > 0) {
				return win;
			}
		} catch (e) {
			return win;
		}
	}
	return null;
}

/**
 * @param {number} ms
 */
function sleepMs(ms) {
	GLib.usleep(ms * 1000);
}

function main() {
	smokeLog('meta-smoke: launch -> fetch -> minimize -> unminimize');

	const display = getDisplay();
	launchApp(display);

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	let win = null;

	while (GLib.get_monotonic_time() < deadline) {
		win = findTargetWindow(display);
		if (win !== null) {
			break;
		}
		sleepMs(POLL_MS);
	}

	if (win === null) {
		throw new Error(
			`no Meta.Window within ${WAIT_MS}ms after launch`
		);
	}

	let title = '';
	let wmClass = '';
	try {
		const t = win.get_title();
		const c = win.get_wm_class();
		title = t === null ? '' : '' + t;
		wmClass = c === null ? '' : '' + c;
	} catch (e) {
		title = '<non-utf8>';
		wmClass = '<non-utf8>';
	}
	smokeLog('fetch: title=' + title + ' wm_class=' + wmClass);

	if (GLib.getenv('GI_META_SMOKE_MINIMIZE') === '1') {
		const holdMs = holdMsBeforeMinimize();
		smokeLog('hold: ' + holdMs + 'ms before minimize');
		sleepMs(holdMs);
		win.minimize();
		smokeLog('put: minimize() ok');
		smokeLog('hold: ' + holdMs + 'ms before unminimize');
		sleepMs(holdMs);
		win.unminimize();
		smokeLog('put: unminimize() ok');
	} else {
		smokeLog('put: skip minimize (set GI_META_SMOKE_MINIMIZE=1 to enable)');
	}
}

main();
