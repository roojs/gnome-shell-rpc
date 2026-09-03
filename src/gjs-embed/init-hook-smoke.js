import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import 'resource:///org/gnome/shell/ui/environment.js';

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		console.log('init-hook-smoke: idle ok');
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log('init-hook-smoke: hook registered');
