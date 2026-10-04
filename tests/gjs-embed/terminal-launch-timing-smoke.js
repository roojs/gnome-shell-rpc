/**
 * Time one Shell.App.launch of GNOME Terminal on a nested mutter.
 *
 * No overview. The product path is Shell.App.launch →
 * Gsr-Mutter-AppLaunch.launch_desktop_file. Logs when that RPC returns,
 * when org.gnome.Terminal is owned, and when Meta sees a new NORMAL window.
 *
 *   GSR_WESTON_MODE=prove GSR_WESTON_AUTO_CLOSE=1 \
 *   GSR_NESTED_STAYUP=1 GSR_NESTED_TIMEOUT=50 \
 *   GI_META_SMOKE=terminal-launch-timing-smoke \
 *     ./scripts/weston-gsr-session.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { Gio, GLib, Meta, Shell } = imports.gi;

const SMOKE = 'terminal-launch-timing-smoke';
const APP_ID = 'org.gnome.Terminal.desktop';
const BUS_NAME = 'org.gnome.Terminal';
const WAIT_MS = 40000;

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
		if (windowType(w) === Meta.WindowType.NORMAL)
			n++;
	}
	return n;
}

function nameOwned() {
	try {
		const reply = Gio.DBus.session.call_sync(
			'org.freedesktop.DBus',
			'/org/freedesktop/DBus',
			'org.freedesktop.DBus',
			'NameHasOwner',
			new GLib.Variant('(s)', [BUS_NAME]),
			new GLib.VariantType('(b)'),
			Gio.DBusCallFlags.NONE,
			200,
			null);
		return reply.get_child_value(0).get_boolean();
	} catch (e) {
		return false;
	}
}

function main() {
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	const app = Shell.AppSystem.get_default().lookup_app(APP_ID);
	if (app == null)
		throw new Error('lookup_app ' + APP_ID + ' failed');
	const baseline = countNormalWindows(display);
	const t0 = GLib.get_monotonic_time();
	smokeLog('baseline-normal=' + baseline + ' name-owned=' + nameOwned());
	smokeLog('launch begin');
	let ok = false;
	try {
		ok = app.launch(0, -1, Shell.AppLaunchGpu.APP_PREF);
	} catch (e) {
		smokeLog('launch threw ' + e);
		throw e;
	}
	const launchMs = Math.round((GLib.get_monotonic_time() - t0) / 1000);
	smokeLog('launch returned ' + ok + ' ms=' + launchMs);
	if (!ok)
		throw new Error('launch returned false');

	const deadline = t0 + WAIT_MS * 1000;
	let owned = false;
	let mapped = false;
	let lastBeat = t0;
	while (GLib.get_monotonic_time() < deadline) {
		const now = GLib.get_monotonic_time();
		if (!owned && nameOwned()) {
			owned = true;
			smokeLog('name-owned ms=' + Math.round((now - t0) / 1000));
		}
		const normal = countNormalWindows(display);
		if (!mapped && normal > baseline) {
			mapped = true;
			smokeLog('window-normal=' + normal + ' ms=' + Math.round((now - t0) / 1000));
		}
		if (now - lastBeat >= 2 * GLib.TIME_SPAN_SECOND) {
			lastBeat = now;
			smokeLog('beat ms=' + Math.round((now - t0) / 1000)
				+ ' owned=' + owned + ' normal=' + normal);
		}
		if (owned && mapped)
			break;
		GLib.usleep(250 * 1000);
	}
	smokeLog('done owned=' + owned + ' mapped=' + mapped
		+ ' ms=' + Math.round((GLib.get_monotonic_time() - t0) / 1000));
	if (!owned || !mapped)
		throw new Error('miss owned=' + owned + ' mapped=' + mapped);
	smokeLog('ok');
}

main();
