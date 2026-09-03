/**
 * Dissect main.js import graph without full init.js.
 *
 *   GI_META_SMOKE=main-dissect-smoke \
 *   GI_MAIN_SMOKE_MODULE=messageList.js \
 *     dbus-run-session ./build/src/mutter-rpc --wayland --nested
 *
 * Module path is under resource:///org/gnome/shell/ui/ unless it contains /.
 */
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import 'resource:///org/gnome/shell/ui/environment.js';

const moduleName = GLib.getenv('GI_MAIN_SMOKE_MODULE');
if (moduleName == null || moduleName.length === 0) {
	console.error('main-dissect-smoke: set GI_MAIN_SMOKE_MODULE (e.g. messageList.js)');
	global.context.run_main_loop();
}

const moduleUrl = moduleName.includes('/')
	? moduleName
	: `resource:///org/gnome/shell/ui/${moduleName}`;

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import(moduleUrl).then(mod => {
			console.log(`main-dissect-smoke: loaded ${moduleName}`, typeof mod);
		}).catch(e => {
			console.error(`main-dissect-smoke: import ${moduleName} failed`, e);
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log(`main-dissect-smoke: will import ${moduleUrl}`);
