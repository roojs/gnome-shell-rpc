/**
 * Log every GObject.registerClass during a module import — pinpoints which
 * registration precedes heap corruption.
 *
 *   GI_MAIN_SMOKE_MODULE=panel.js \
 *     ./scripts/gi-rpc-smoke.sh run src/gjs-embed/register-class-trace-smoke.js
 */
import GLib from 'gi://GLib';

import 'resource:///org/gnome/shell/ui/environment.js';
import { getRegisterClassTraceCount, installRegisterClassTrace } from './register-class-trace-hook.js';
import { runSmokeIdle } from './smoke-exit.js';

const moduleName = GLib.getenv('GI_MAIN_SMOKE_MODULE');
if (moduleName == null || moduleName.length === 0) {
	console.error('register-class-trace: set GI_MAIN_SMOKE_MODULE');
	global.context.run_main_loop();
}

const moduleUrl = moduleName.includes('/')
	? moduleName
	: `resource:///org/gnome/shell/ui/${moduleName}`;

installRegisterClassTrace();

runSmokeIdle(async () => {
	try {
		await import(moduleUrl);
		console.log(`register-class-trace: loaded ${moduleName} (${getRegisterClassTraceCount()} registrations)`);
	} catch (e) {
		console.error(`register-class-trace: import ${moduleName} failed`, e);
		throw e;
	}
});

console.log(`register-class-trace: will import ${moduleUrl}`);
