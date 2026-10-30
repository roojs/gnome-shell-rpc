/**
 * Lock, open the password page, type a password, press Enter.
 * The shield has to leave the locked state.
 *
 * Pass: `lock-screen-unlock-smoke/ui/init: ok`
 * A dummy password is `ok submitted` when GDM answers.
 * Fail: `lock-screen-unlock-smoke/ui/init: miss <reason>`
 *
 *   GSR_NESTED_TIMEOUT=45 \
 *     GI_META_SMOKE=lock-screen-unlock-smoke/ui/init \
 *     ./scripts/weston-gsr-prove.sh
 */

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';
import * as LoginManager from 'resource:///org/gnome/shell/misc/loginManager.js';

const SMOKE = 'lock-screen-unlock-smoke/ui/init';

const STATUS = [
	'not-verifying',
	'verifying',
	'failed',
	'succeeded',
	'cancelled',
	'in-progress',
];

const PASSWORD_KEYS = [
	Clutter.KEY_s,
	Clutter.KEY_e,
	Clutter.KEY_c,
	Clutter.KEY_r,
	Clutter.KEY_e,
	Clutter.KEY_t,
	Clutter.KEY_Return,
];

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
 * @returns {string}
 */
function gdmVersion() {
	try {
		const params = GLib.Variant.new('(ss)', [
			'org.gnome.DisplayManager.Manager',
			'Version',
		]);
		const result = Gio.DBus.system.call_sync(
			'org.gnome.DisplayManager',
			'/org/gnome/DisplayManager/Manager',
			'org.freedesktop.DBus.Properties',
			'Get', params, null,
			Gio.DBusCallFlags.NONE,
			-1, null);
		return result.deepUnpack()[0].deepUnpack();
	} catch (e) {
		return 'error ' + formatError(e);
	}
}

/**
 * @param {object} shield
 * @returns {string}
 */
function shieldState(shield) {
	if (shield == null)
		return 'shield=null';
	const actor = shield.actor;
	let mapped = false;
	let visible = false;
	try {
		visible = actor.visible === true;
		mapped = actor.mapped === true;
	} catch (e) {
		return 'shield actor ' + formatError(e);
	}
	return 'active=' + shield.active
		+ ' locked=' + shield.locked
		+ ' visible=' + visible
		+ ' mapped=' + mapped;
}

/**
 * @param {object} main
 * @returns {{button: object|null, names: string}}
 */
function findLockButton(main) {
	const box = main.panel?.statusArea?.quickSettings
		?._system?._systemItem?.child ?? null;
	if (box == null)
		return {button: null, names: 'no-system-item'};
	const names = [];
	let button = null;
	for (const child of box) {
		const name = child.accessible_name ?? '';
		names.push(name + '=' + child.visible);
		if (name === 'Lock Screen')
			button = child;
	}
	return {button, names: names.join(',')};
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

function pokePointer() {
	const seat = global.stage.context.get_backend().get_default_seat();
	const pointer = seat.create_virtual_device(
		Clutter.InputDeviceType.POINTER_DEVICE);
	const now = GLib.get_monotonic_time();
	pointer.notify_absolute_motion(now, 200, 200);
	pointer.notify_absolute_motion(now + 20000, 420, 280);
}

/**
 * @param {object} keyboard
 * @param {number} keyval
 */
function pressKeyval(keyboard, keyval) {
	const now = GLib.get_monotonic_time();
	keyboard.notify_keyval(now, keyval, Clutter.KeyState.PRESSED);
	keyboard.notify_keyval(now + 10000, keyval, Clutter.KeyState.RELEASED);
}

/**
 * Length and status only. The entry text is the password.
 *
 * @param {object} shield
 * @returns {string}
 */
function authState(shield) {
	const auth = shield._dialog?._authPrompt ?? null;
	if (auth == null)
		return 'auth=null';
	const entry = auth._entry;
	let len = -1;
	let hint = '';
	let reactive = false;
	try {
		const text = entry?.get_text?.() ?? '';
		len = text.length;
		hint = entry?.hint_text ?? '';
		reactive = entry?.reactive === true;
	} catch (e) {
		return 'auth-read ' + formatError(e);
	}
	const status = STATUS[auth.verificationStatus] ?? String(auth.verificationStatus);
	let message = '';
	try {
		message = auth._message?.text ?? '';
	} catch (e) {
		message = 'message-read-failed';
	}
	const focus = global.stage.key_focus;
	const focusStyle = focus?.style_class ?? 'null';
	return 'status=' + status
		+ ' len=' + len
		+ ' reactive=' + reactive
		+ ' hint=' + hint
		+ ' message=' + message
		+ ' focus=' + focusStyle;
}

/**
 * @param {object} shield
 */
function typePassword(shield) {
	const before = authState(shield);
	smokeLog('before-type ' + before + ' ' + shieldState(shield));
	let keyboard;
	try {
		const seat = global.stage.context.get_backend().get_default_seat();
		keyboard = seat.create_virtual_device(
			Clutter.InputDeviceType.KEYBOARD_DEVICE);
	} catch (e) {
		finish('miss keyboard ' + formatError(e) + ' ' + before);
		return;
	}

	let index = 0;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 80, () => {
		if (index < PASSWORD_KEYS.length) {
			try {
				pressKeyval(keyboard, PASSWORD_KEYS[index]);
			} catch (e) {
				finish('miss key ' + formatError(e) + ' ' + authState(shield));
				return GLib.SOURCE_REMOVE;
			}
			index += 1;
			return GLib.SOURCE_CONTINUE;
		}
		const afterAt = GLib.get_monotonic_time() + 4 * GLib.TIME_SPAN_SECOND;
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
			const state = authState(shield) + ' ' + shieldState(shield);
			if (shield.locked !== true) {
				finish('ok unlocked ' + state);
				return GLib.SOURCE_REMOVE;
			}
			const auth = shield._dialog?._authPrompt ?? null;
			let message = '';
			try {
				message = auth?._message?.text ?? '';
			} catch (e) {
				message = '';
			}
			if (message.length > 0) {
				finish('ok submitted ' + state);
				return GLib.SOURCE_REMOVE;
			}
			if (GLib.get_monotonic_time() < afterAt)
				return GLib.SOURCE_CONTINUE;
			const len = auth?._entry?.get_text?.().length ?? -1;
			if (len < 1)
				finish('miss entry-empty ' + state);
			else
				finish('miss still-locked ' + state);
			return GLib.SOURCE_REMOVE;
		});
		return GLib.SOURCE_REMOVE;
	});
}

/**
 * @param {object} main
 */
function runProve(main) {
	const canLock = LoginManager.canLock();
	const version = gdmVersion();
	smokeLog('canLock=' + canLock + ' gdm=' + version);

	const shield = main.screenShield;
	if (shield == null) {
		finish('miss no-shield canLock=' + canLock);
		return;
	}

	const found = findLockButton(main);
	smokeLog('chrome ' + found.names);
	if (found.button == null || found.button.visible !== true) {
		finish('miss no-button');
		return;
	}

	try {
		found.button.emit('clicked', found.button);
	} catch (e) {
		finish('miss click ' + formatError(e));
		return;
	}

	const blackAt = GLib.get_monotonic_time() + 4 * GLib.TIME_SPAN_SECOND;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
		const fade = shield._shortLightbox;
		const black = fade != null && fade.active === true && fade.opacity >= 200;
		if (!black) {
			if (GLib.get_monotonic_time() < blackAt)
				return GLib.SOURCE_CONTINUE;
			finish('miss fade-stuck ' + fadeState(shield) + ' ' + shieldState(shield));
			return GLib.SOURCE_REMOVE;
		}
		smokeLog('black ' + fadeState(shield) + ' ' + shieldState(shield));
		try {
			pokePointer();
		} catch (e) {
			finish('miss poke ' + formatError(e) + ' ' + fadeState(shield));
			return GLib.SOURCE_REMOVE;
		}
		const wakeAt = GLib.get_monotonic_time() + 2 * GLib.TIME_SPAN_SECOND;
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
			const opacity = shield._shortLightbox?.opacity ?? -1;
			if (opacity < 40) {
				try {
					const seat = global.stage.context.get_backend().get_default_seat();
					const keyboard = seat.create_virtual_device(
						Clutter.InputDeviceType.KEYBOARD_DEVICE);
					pressKeyval(keyboard, Clutter.KEY_a);
				} catch (e) {
					finish('miss key ' + formatError(e));
					return GLib.SOURCE_REMOVE;
				}
				const promptAt = GLib.get_monotonic_time()
					+ GLib.TIME_SPAN_SECOND;
				GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
					const box = shield._dialog?._promptBox;
					if (box != null && box.visible === true) {
						smokeLog('prompt ' + fadeState(shield) + ' ' + shieldState(shield));
						GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1500, () => {
							typePassword(shield);
							return GLib.SOURCE_REMOVE;
						});
						return GLib.SOURCE_REMOVE;
					}
					if (GLib.get_monotonic_time() < promptAt)
						return GLib.SOURCE_CONTINUE;
					finish('miss key-no-prompt ' + fadeState(shield)
						+ ' ' + shieldState(shield));
					return GLib.SOURCE_REMOVE;
				});
				return GLib.SOURCE_REMOVE;
			}
			if (GLib.get_monotonic_time() < wakeAt)
				return GLib.SOURCE_CONTINUE;
			finish('miss stayed-black ' + fadeState(shield) + ' ' + shieldState(shield));
			return GLib.SOURCE_REMOVE;
		});
		return GLib.SOURCE_REMOVE;
	});
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => {
				const deadline = GLib.get_monotonic_time()
					+ 25 * GLib.TIME_SPAN_SECOND;
				GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
					const ready = main.panel != null
						&& main.panel.statusArea != null
						&& main.panel.statusArea.quickSettings != null;
					if (!ready && GLib.get_monotonic_time() < deadline)
						return GLib.SOURCE_CONTINUE;
					const started = main.layoutManager != null
						&& main.layoutManager._startingUp === false;
					if ((!ready || !started)
							&& GLib.get_monotonic_time() < deadline)
						return GLib.SOURCE_CONTINUE;
					if (!ready) {
						finish('miss no-quick-settings');
						return GLib.SOURCE_REMOVE;
					}
					if (!started) {
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
