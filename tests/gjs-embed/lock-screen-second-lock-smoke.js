/**
 * Lock, show the password page, leave the shield, lock again.
 * The second lock has to show the password page too.
 *
 * Pass: `lock-screen-second-lock-smoke/ui/init: ok`
 * Fail: `lock-screen-second-lock-smoke/ui/init: miss <reason>`
 *
 *   GSR_WESTON_MODE=prove GSR_WESTON_AUTO_CLOSE=1 GSR_NESTED_TIMEOUT=70 \
 *     GI_META_SMOKE=lock-screen-second-lock-smoke/ui/init \
 *     timeout --foreground -k 2 90 ./scripts/weston-gsr-session.sh
 */

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'lock-screen-second-lock-smoke/ui/init';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

/**
 * @param {string} reason
 */
function finish(reason) {
	smokeLog(reason);
	global.context.terminate();
}

/**
 * @param {object} shield
 * @returns {string}
 */
function fadeState(shield) {
	const fade = shield._shortLightbox;
	if (fade == null)
		return 'no-fade';
	return 'opacity=' + fade.opacity + ' active=' + fade.active;
}

/**
 * @param {object} main
 * @returns {object|null}
 */
function lockButton(main) {
	const box = main.panel?.statusArea?.quickSettings
		?._system?._systemItem?.child ?? null;
	if (box == null)
		return null;
	for (const child of box) {
		if ((child.accessible_name ?? '') === 'Lock Screen')
			return child;
	}
	return null;
}

function pokePointer() {
	const seat = global.stage.context.get_backend().get_default_seat();
	const pointer = seat.create_virtual_device(
		Clutter.InputDeviceType.POINTER_DEVICE);
	const now = GLib.get_monotonic_time();
	pointer.notify_absolute_motion(now, 200, 200);
	pointer.notify_absolute_motion(now + 20000, 420, 280);
}

/**
 * @param {number} keyval
 */
function pressKey(keyval) {
	const seat = global.stage.context.get_backend().get_default_seat();
	const keyboard = seat.create_virtual_device(
		Clutter.InputDeviceType.KEYBOARD_DEVICE);
	const now = GLib.get_monotonic_time();
	keyboard.notify_keyval(now, keyval, Clutter.KeyState.PRESSED);
	keyboard.notify_keyval(now + 10000, keyval, Clutter.KeyState.RELEASED);
}

/**
 * Wait until the curtain is black, wake it, then require the password page.
 *
 * @param {object} shield
 * @param {string} which
 * @param {() => void} onPrompt
 */
function waitForPrompt(shield, which, onPrompt) {
	const blackAt = GLib.get_monotonic_time() + 4 * GLib.TIME_SPAN_SECOND;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
		const fade = shield._shortLightbox;
		const black = fade != null && fade.active === true && fade.opacity >= 200;
		if (!black) {
			if (GLib.get_monotonic_time() < blackAt)
				return GLib.SOURCE_CONTINUE;
			finish('miss ' + which + '-fade-stuck ' + fadeState(shield));
			return GLib.SOURCE_REMOVE;
		}
		smokeLog(which + '-black ' + fadeState(shield));
		try {
			pokePointer();
		} catch (e) {
			finish('miss ' + which + '-poke ' + formatError(e));
			return GLib.SOURCE_REMOVE;
		}
		const wakeAt = GLib.get_monotonic_time() + 2 * GLib.TIME_SPAN_SECOND;
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
			const opacity = shield._shortLightbox?.opacity ?? -1;
			if (opacity < 40) {
				try {
					pressKey(Clutter.KEY_a);
				} catch (e) {
					finish('miss ' + which + '-key ' + formatError(e));
					return GLib.SOURCE_REMOVE;
				}
				const promptAt = GLib.get_monotonic_time() + GLib.TIME_SPAN_SECOND;
				GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
					const box = shield._dialog?._promptBox;
					if (box != null && box.visible === true) {
						smokeLog(which + '-prompt ' + fadeState(shield));
						onPrompt();
						return GLib.SOURCE_REMOVE;
					}
					if (GLib.get_monotonic_time() < promptAt)
						return GLib.SOURCE_CONTINUE;
					finish('miss ' + which + '-no-prompt ' + fadeState(shield));
					return GLib.SOURCE_REMOVE;
				});
				return GLib.SOURCE_REMOVE;
			}
			if (GLib.get_monotonic_time() < wakeAt)
				return GLib.SOURCE_CONTINUE;
			finish('miss ' + which + '-stayed-black ' + fadeState(shield));
			return GLib.SOURCE_REMOVE;
		});
		return GLib.SOURCE_REMOVE;
	});
}

/**
 * @param {object} main
 * @param {object} shield
 */
function lockAgain(main, shield) {
	try {
		shield.deactivate(false);
	} catch (e) {
		finish('miss deactivate ' + formatError(e));
		return;
	}
	const deskAt = GLib.get_monotonic_time() + 4 * GLib.TIME_SPAN_SECOND;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
		if (shield.locked === true || shield._dialog != null) {
			if (GLib.get_monotonic_time() < deskAt)
				return GLib.SOURCE_CONTINUE;
			finish('miss still-locked-after-deactivate dialog='
				+ (shield._dialog != null));
			return GLib.SOURCE_REMOVE;
		}
		const button = lockButton(main);
		if (button == null) {
			finish('miss no-button-second');
			return GLib.SOURCE_REMOVE;
		}
		try {
			button.emit('clicked', button);
		} catch (e) {
			finish('miss second-click ' + formatError(e));
			return GLib.SOURCE_REMOVE;
		}
		waitForPrompt(shield, 'second', () => {
			finish('ok second-prompt ' + fadeState(shield));
		});
		return GLib.SOURCE_REMOVE;
	});
}

/**
 * @param {object} main
 */
function runProve(main) {
	const shield = main.screenShield;
	const button = lockButton(main);
	if (shield == null || button == null) {
		finish('miss no-shield');
		return;
	}
	try {
		button.emit('clicked', button);
	} catch (e) {
		finish('miss click ' + formatError(e));
		return;
	}
	waitForPrompt(shield, 'first', () => lockAgain(main, shield));
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => {
				const deadline = GLib.get_monotonic_time()
					+ 25 * GLib.TIME_SPAN_SECOND;
				GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
					const ready = main.panel?.statusArea?.quickSettings != null
						&& main.layoutManager?._startingUp === false;
					if (!ready && GLib.get_monotonic_time() < deadline)
						return GLib.SOURCE_CONTINUE;
					if (!ready) {
						finish('miss startup-timeout');
						return GLib.SOURCE_REMOVE;
					}
					runProve(main);
					return GLib.SOURCE_REMOVE;
				});
			});
		}).catch(e => {
			finish('miss start ' + formatError(e));
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
