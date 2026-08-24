/**
 * 0.5.3 partial Clutter POC — leased WindowActor.show() over RPC.
 *
 * Requires meta-mini typelib with WindowActor / Compositor stubs and a
 * running gnome-shell-rpc compositor (nested).
 *
 * GI_META_SMOKE_CLUTTER=1 ./build/src/gjs-embed --debug src/gjs-embed/clutter-smoke.js
 */

imports.gi.versions.Meta = '16';

const { GLib, Meta } = imports.gi;

const SMOKE_DOMAIN = 'clutter-smoke';
const APP_CMD = GLib.getenv('GI_META_SMOKE_CMD') || 'gtk4-demo';
const WAIT_MS = 8000;
const POLL_MS = 200;

function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

function sleepMs(ms) {
	GLib.usleep(ms * 1000);
}

function launchApp(display) {
	const startup = display.get_startup_notification();
	const launcher = startup.create_launcher();
	const Gio = imports.gi.Gio;
	const app = Gio.AppInfo.create_from_commandline(
		APP_CMD,
		null,
		Gio.AppInfoCreateFlags.NONE
	);
	if (app === null) {
		throw new Error('launch failed: ' + APP_CMD);
	}
	if (!app.launch([], launcher)) {
		throw new Error('AppInfo.launch failed');
	}
	smokeLog('launch: ' + APP_CMD);
}

function main() {
	smokeLog('compositor.get_window_actors → show() (Clutter lease POC)');

	const display = Meta.get_display();
	launchApp(display);

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	var actors = [];

	while (GLib.get_monotonic_time() < deadline) {
		const compositor = display.get_compositor();
		const list = compositor.get_window_actors();
		if (list !== null && list.length > 0) {
			actors = list;
			break;
		}
		sleepMs(POLL_MS);
	}

	if (actors.length === 0) {
		throw new Error('no WindowActor within ' + WAIT_MS + 'ms');
	}

	const actor = actors[0];
	smokeLog('actors=' + actors.length + ' calling show() on first');
	actor.show();
	const visible = actor.visible;
	smokeLog('after show(): visible=' + visible);
}

main();
