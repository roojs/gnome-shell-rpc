/**
 * Log every GObject.registerClass during a module import — pinpoints which
 * registration precedes heap corruption.
 *
 *   GI_META_SMOKE=register-class-trace-smoke \
 *   GI_MAIN_SMOKE_MODULE=panel.js \
 *     dbus-run-session ./build/src/mutter-rpc --wayland --nested
 */
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';

import 'resource:///org/gnome/shell/ui/environment.js';

const moduleName = GLib.getenv('GI_MAIN_SMOKE_MODULE');
if (moduleName == null || moduleName.length === 0) {
	console.error('register-class-trace: set GI_MAIN_SMOKE_MODULE');
	global.context.run_main_loop();
}

const moduleUrl = moduleName.includes('/')
	? moduleName
	: `resource:///org/gnome/shell/ui/${moduleName}`;

let seq = 0;

function parentChain(klass) {
	const parts = [];
	let cur = klass;
	while (cur != null) {
		const name = cur.name?.length ? cur.name : String(cur);
		parts.push(name);
		cur = Object.getPrototypeOf(cur);
		if (parts.length > 12)
			break;
	}
	return parts.join(' <- ');
}

const origRegisterClass = GObject.registerClass;
GObject.registerClass = function registerClassTrace(...args) {
	let meta = null;
	let klass = null;
	if (args.length === 1) {
		klass = args[0];
	} else if (args.length === 2) {
		meta = args[0];
		klass = args[1];
	} else if (args.length === 3) {
		meta = args[0];
		klass = args[2];
	} else {
		console.log(`register-class-trace: #${++seq} registerClass(???)`);
		return origRegisterClass.apply(this, args);
	}

	const className = klass?.name ?? '(anonymous)';
	const implementsList = meta?.Implements?.map(i => i.name ?? String(i)).join(',') ?? '';
	let from = '';
	try {
		const stack = new Error().stack ?? '';
		const line = stack.split('\n').find(l => l.includes('/org/gnome/shell/'));
		if (line != null) {
			const m = line.match(/org\/gnome\/shell\/(.+\.js)/);
			if (m)
				from = ` @${m[1]}`;
		}
	} catch (_e) {
	}
	console.log(
		`register-class-trace: #${++seq} ${className} extends ${parentChain(klass)}` +
		(implementsList.length ? ` Implements=[${implementsList}]` : '') +
		from,
	);
	return origRegisterClass.apply(this, args);
};

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import(moduleUrl).then(mod => {
			console.log(`register-class-trace: loaded ${moduleName} (${seq} registrations)`);
		}).catch(e => {
			console.error(`register-class-trace: import ${moduleName} failed`, e);
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log(`register-class-trace: will import ${moduleUrl}`);
