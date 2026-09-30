/**
 * 0.5.6 B3 — Window.foreach_transient (nested mutter only).
 *
 *   GI_META_SMOKE=transient-smoke dbus-run-session ./build/src/gnome-shell-rpc --debug --wayland --nested
 *
 * Walks transients of every known window. An empty walk still proves the
 * Helper RPC; a non-zero count proves Live.Invoke + bool reply.
 */

imports.gi.versions.Meta = '16';

const { GLib, Gio, Meta } = imports.gi;

const SMOKE_DOMAIN = 'transient-smoke';
const APP_CMD = GLib.getenv('GI_META_SMOKE_CMD') || 'gtk4-demo --run=dialog';
const WAIT_MS = 8000;
const POLL_MS = 200;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

function sleepMs(ms) {
	GLib.usleep(ms * 1000);
}

function launchApp(display) {
	const startup = display.get_startup_notification();
	const launcher = startup.create_launcher();
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
	const display = Meta.get_display();
	launchApp(display);

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	var wins = [];
	while (GLib.get_monotonic_time() < deadline) {
		const list = display.list_all_windows();
		if (list !== null && list.length > 0) {
			wins = list;
			if (list.length >= 2) {
				break;
			}
		}
		sleepMs(POLL_MS);
	}
	if (wins.length === 0) {
		throw new Error('transient-smoke: no windows');
	}

	var n = 0;
	for (var i = 0; i < wins.length; i++) {
		wins[i].foreach_transient((w) => {
			n++;
			smokeLog('transient title=' + w.get_title());
			return true;
		});
	}
	smokeLog('windows=' + wins.length + ' transients=' + n);
	smokeLog('ok');
}

main();
