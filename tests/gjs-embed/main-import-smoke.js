import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import 'resource:///org/gnome/shell/ui/environment.js';

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			console.log('main-import-smoke: main loaded', typeof main.start);
		}).catch(e => {
			console.error('main-import-smoke: import failed', e);
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log('main-import-smoke: hook registered');
