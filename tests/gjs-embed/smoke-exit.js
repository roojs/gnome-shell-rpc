/**
 * Exit gnome-shell-rpc smokes — call {@link Meta.Context.terminate}.
 */
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

/**
 * Quit after smoke work.
 *
 * @param {string} [reason] logged when falling back to terminate_with_error
 */
export function quitSmokeMainLoop(reason = 'smoke done') {
	const ctx = global.context;
	if (ctx == null) {
		console.error('smoke-exit: global.context is missing');
		return;
	}
	if (typeof ctx.terminate === 'function') {
		ctx.terminate();
		return;
	}
	if (typeof ctx.terminate_with_error === 'function') {
		const err = new GLib.Error(Gio.IOErrorEnum, Gio.IOErrorEnum.FAILED, reason);
		ctx.terminate_with_error(err);
		return;
	}
	console.error('smoke-exit: Meta.Context has no quit API');
}

/**
 * Run fn on the next idle tick, then {@link quitSmokeMainLoop}.
 *
 * @param {() => (void|Promise<void>)} fn smoke body
 */
export function runSmokeIdle(fn) {
	imports._promiseNative.setMainLoopHook(() => {
		GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
			try {
				const result = fn();
				if (result != null && typeof result.then === 'function') {
					result.then(() => quitSmokeMainLoop()).catch(e => {
						console.error('smoke-exit: idle task failed', e);
						quitSmokeMainLoop('smoke failed');
					});
				} else {
					quitSmokeMainLoop();
				}
			} catch (e) {
				console.error('smoke-exit: idle task failed', e);
				quitSmokeMainLoop('smoke failed');
			}
			return GLib.SOURCE_REMOVE;
		});
		global.context.run_main_loop();
	});
}
