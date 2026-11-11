/**
 * Desktop Icons sets its Wayland client only after spawnv returns.
 * A window that maps during that call is ignored, the 3s timer
 * kills the process, and a second desktop is launched.
 *
 * Pass: `ding-spawn-map: ok` — the probe window maps after spawn
 * returns and the client owns it.
 * Fail: `ding-spawn-map: miss …`
 *
 *   GI_META_SMOKE=ding-spawn-map ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const { Gio, GLib, Meta, Shell } = imports.gi;

const SMOKE = 'ding-spawn-map';
const TITLE = 'ding-probe';
const WAIT_MS = parseInt(GLib.getenv('GI_META_SMOKE_WAIT_MS') || '8000', 10);
const PY = [
	'python3', '-c',
	'import gi\n'
	+ 'gi.require_version("Gtk", "3.0")\n'
	+ 'from gi.repository import Gtk\n'
	+ 'w = Gtk.Window(title="' + TITLE + '")\n'
	+ 'w.set_default_size(200, 100)\n'
	+ 'w.show_all()\n'
	+ 'Gtk.main()\n',
];

function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function windowOf(actor) {
	if (actor == null)
		return null;
	return actor.meta_window ?? actor.get_meta_window?.() ?? null;
}

function titleOf(window) {
	if (window == null)
		return '';
	if (typeof window.get_title === 'function')
		return window.get_title() ?? '';
	return window.title ?? '';
}

function main() {
	const globalObj = Shell.Global.get();
	const display = globalObj.get_display();
	const wm = globalObj.window_manager;
	if (wm == null)
		throw new Error('window_manager is null');

	let spawnReturned = false;
	let waylandClient = null;
	let mapsBefore = 0;
	let mapsAfter = 0;
	let owns = 'unset';
	let done = false;

	wm.connect('map', (_wm, actor) => {
		const window = windowOf(actor);
		const title = titleOf(window);
		smokeLog('map title=' + title + ' spawnReturned=' + spawnReturned);
		if (title !== TITLE)
			return;
		if (!spawnReturned)
			mapsBefore++;
		else
			mapsAfter++;
		if (waylandClient == null) {
			owns = 'no-client';
			return;
		}
		try {
			owns = String(waylandClient.owns_window(window));
		} catch (e) {
			owns = 'err ' + (e != null && e.message != null ? e.message : e);
		}
		if (spawnReturned)
			done = true;
	});

	const launcher = new Gio.SubprocessLauncher({
		flags: Gio.SubprocessFlags.STDOUT_PIPE
			| Gio.SubprocessFlags.STDERR_MERGE,
	});
	try {
		waylandClient = Meta.WaylandClient.new(globalObj.context, launcher);
		waylandClient.spawnv(display, PY);
	} catch (e) {
		smokeLog('miss launch ' + (e != null && e.message != null ? e.message : e));
		return;
	}
	spawnReturned = true;
	smokeLog('spawn-returned mapsBefore=' + mapsBefore + ' owns=' + owns);

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	const ctx = GLib.MainContext.default();
	while (!done && GLib.get_monotonic_time() < deadline) {
		while (ctx.pending())
			ctx.iteration(false);
		if (!done)
			GLib.usleep(50 * 1000);
	}

	smokeLog('mapsBefore=' + mapsBefore + ' mapsAfter=' + mapsAfter
		+ ' owns=' + owns);
	if (mapsBefore > 0) {
		smokeLog('miss mapped-during-spawn owns=' + owns);
		return;
	}
	if (mapsAfter < 1) {
		smokeLog('miss no-map');
		return;
	}
	if (owns !== 'true') {
		smokeLog('miss owns=' + owns);
		return;
	}
	smokeLog('ok');
}

main();
