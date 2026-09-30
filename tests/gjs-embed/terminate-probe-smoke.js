import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import 'resource:///org/gnome/shell/ui/environment.js';
import { quitSmokeMainLoop } from './smoke-exit.js';

print(`terminate-probe: terminate=${typeof global.context.terminate}`);

GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
	print('terminate-probe: idle quit');
	quitSmokeMainLoop('terminate-probe done');
	return GLib.SOURCE_REMOVE;
});

print('terminate-probe: entering run_main_loop');
global.context.run_main_loop();
print('terminate-probe: left run_main_loop');
