/**
 * Install a {@link GObject.registerClass} trace — shared by init and module smokes.
 */
import GObject from 'gi://GObject';

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

function sourceFileFromStack() {
	try {
		const stack = new Error().stack ?? '';
		const line = stack.split('\n').find(l => l.includes('/org/gnome/shell/'));
		if (line != null) {
			const m = line.match(/org\/gnome\/shell\/(.+\.js)/);
			if (m)
				return ` @${m[1]}`;
		}
	} catch (_e) {
	}
	return '';
}

/**
 * Log every registerClass call after this returns.
 *
 * @returns {() => number} registration count so far
 */
export function installRegisterClassTrace() {
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
		console.log(
			`register-class-trace: #${++seq} ${className} extends ${parentChain(klass)}` +
			(implementsList.length ? ` Implements=[${implementsList}]` : '') +
			sourceFileFromStack(),
		);
		return origRegisterClass.apply(this, args);
	};
	return () => seq;
}

export function getRegisterClassTraceCount() {
	return seq;
}
