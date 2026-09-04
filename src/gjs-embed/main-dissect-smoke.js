/**
 * Dissect main.js import graph without full init.js.
 *
 *   GI_MAIN_SMOKE_MODULE=messageList.js \
 *     ./scripts/gi-rpc-smoke.sh run src/gjs-embed/main-dissect-smoke.js
 */
import GLib from 'gi://GLib';

import 'resource:///org/gnome/shell/ui/environment.js';
import { runSmokeIdle } from './smoke-exit.js';

const moduleName = GLib.getenv('GI_MAIN_SMOKE_MODULE');
if (moduleName == null || moduleName.length === 0) {
	console.error('main-dissect-smoke: set GI_MAIN_SMOKE_MODULE (e.g. messageList.js)');
	global.context.run_main_loop();
}

const moduleUrl = moduleName.includes('/')
	? moduleName
	: `resource:///org/gnome/shell/ui/${moduleName}`;

runSmokeIdle(async () => {
	try {
		const mod = await import(moduleUrl);
		console.log(`main-dissect-smoke: loaded ${moduleName}`, typeof mod);
	} catch (e) {
		console.error(`main-dissect-smoke: import ${moduleName} failed`, e);
		throw e;
	}
});

console.log(`main-dissect-smoke: will import ${moduleUrl}`);
