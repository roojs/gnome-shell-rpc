/**
 * Import panel.js dependencies one-by-one (same graph, sequential logging).
 *
 *   GI_META_SMOKE=panel-import-bisect-smoke \
 *     dbus-run-session ./build/src/mutter-rpc --wayland --nested
 */
import GLib from 'gi://GLib';

import 'resource:///org/gnome/shell/ui/environment.js';

const steps = [
	'resource:///org/gnome/shell/ui/animation.js',
	'resource:///org/gnome/shell/ui/appMenu.js',
	'resource:///org/gnome/shell/misc/config.js',
	'resource:///org/gnome/shell/ui/ctrlAltTab.js',
	'resource:///org/gnome/shell/ui/dnd.js',
	'resource:///org/gnome/shell/ui/overview.js',
	'resource:///org/gnome/shell/ui/popupMenu.js',
	'resource:///org/gnome/shell/ui/panelMenu.js',
	'resource:///org/gnome/shell/ui/quickSettings.js',
	'resource:///org/gnome/shell/ui/main.js',
	'resource:///org/gnome/shell/misc/util.js',
	'resource:///org/gnome/shell/ui/status/remoteAccess.js',
	'resource:///org/gnome/shell/ui/status/powerProfiles.js',
	'resource:///org/gnome/shell/ui/status/rfkill.js',
	'resource:///org/gnome/shell/ui/status/camera.js',
	'resource:///org/gnome/shell/ui/status/volume.js',
	'resource:///org/gnome/shell/ui/status/brightness.js',
	'resource:///org/gnome/shell/ui/status/system.js',
	'resource:///org/gnome/shell/ui/status/location.js',
	'resource:///org/gnome/shell/ui/status/nightLight.js',
	'resource:///org/gnome/shell/ui/status/darkMode.js',
	'resource:///org/gnome/shell/ui/status/backlight.js',
	'resource:///org/gnome/shell/ui/status/thunderbolt.js',
	'resource:///org/gnome/shell/ui/status/autoRotate.js',
	'resource:///org/gnome/shell/ui/status/backgroundApps.js',
	'resource:///org/gnome/shell/ui/dateMenu.js',
	'resource:///org/gnome/shell/ui/status/accessibility.js',
	'resource:///org/gnome/shell/ui/status/keyboard.js',
	'resource:///org/gnome/shell/ui/status/dwellClick.js',
	'resource:///org/gnome/shell/ui/panel.js',
];

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		(async () => {
			for (const url of steps) {
				console.log(`panel-import-bisect: importing ${url}`);
				await import(url);
				console.log(`panel-import-bisect: ok ${url}`);
			}
			console.log('panel-import-bisect: done');
		})().catch(e => {
			console.error('panel-import-bisect: failed', e);
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log('panel-import-bisect: will run sequential imports');
