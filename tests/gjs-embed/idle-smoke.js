/**
 * 0.5.6 B2 — IdleMonitor add_idle_watch (nested mutter only).
 *
 * Nested compositor already running gnome-shell-rpc:
 *   GI_META_SMOKE=idle-smoke dbus-run-session ./build/src/gnome-shell-rpc --debug --wayland --nested
 */

imports.gi.versions.Meta = '16';

const { GLib, Meta } = imports.gi;

const SMOKE_DOMAIN = 'idle-smoke';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

function main() {
	const backend = Meta.get_display().get_compositor().get_backend();
	const monitor = backend.get_core_idle_monitor();
	let fired = false;
	const id = monitor.add_idle_watch(1, () => {
		fired = true;
		smokeLog('watch fired id=' + id);
	});
	smokeLog('watch id=' + id);
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
		if (!fired) {
			throw new Error('idle-smoke: watch did not fire');
		}
		monitor.remove_watch(id);
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
	smokeLog('ok');
}

main();
