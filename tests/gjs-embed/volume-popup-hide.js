/**
 * Volume / quick-settings pop-down must hide after an outside click.
 *
 *   GI_META_SMOKE=volume-popup-hide ./scripts/weston-gsr-prove.sh
 *
 * The opening click is supposed to leave the menu up. A later press
 * outside it is supposed to hide it. This smoke scores that second press.
 */
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import St from 'gi://St';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'volume-popup-hide/ui/init';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

/**
 * @param {object} actor
 * @returns {string}
 */
function actorBox(actor) {
	if (actor == null)
		return 'null';
	const [x, y] = actor.get_transformed_position();
	return `${x},${y} ${actor.width}x${actor.height} visible=${actor.visible} mapped=${actor.mapped}`;
}

/**
 * Same offset as panel-menu-stay-smoke. Virtual pointer lands short.
 *
 * @param {object} globalObj
 * @param {object} actor
 */
function clickActor(globalObj, actor) {
	const [x, y] = actor.get_transformed_position();
	const cx = x + actor.width / 2 + 38;
	const cy = y + actor.height / 2 + 59;
	smokeLog(`click ${actorBox(actor)} at ${cx},${cy}`);
	globalObj.pointer_click(cx, cy);
}

/**
 * @param {number} ms
 * @param {() => void} fn
 */
function later(ms, fn) {
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
		try {
			fn();
		} catch (e) {
			smokeLog('miss threw ' + formatError(e));
			global.context.terminate();
		}
		return GLib.SOURCE_REMOVE;
	});
}

/**
 * @param {object} menu
 * @returns {string}
 */
function menuState(menu) {
	return `open=${menu.isOpen} actor=${actorBox(menu.actor)}`;
}

/**
 * @param {object} main
 */
function runProve(main) {
	const globalObj = global;
	const quickSettings = main.panel.statusArea.quickSettings;
	if (quickSettings == null || quickSettings.menu == null) {
		smokeLog('miss no-menu');
		global.context.terminate();
		return;
	}
	const menu = quickSettings.menu;
	// An empty QuickSettingsLayout reports (0 - 1) * row_spacing = -12 and
	// mutter aborts on open, before any outside click. One visible row
	// keeps the allocate alive so the hide can be scored.
	if (menu._grid != null) {
		menu._grid.add_child(new St.Widget({width: 40, height: 40}));
		smokeLog('grid children ' + menu._grid.get_n_children());
	}
	const monitor = main.layoutManager.primaryMonitor;
	const outsideX = 8;
	const outsideY = Math.floor(monitor.height / 2);
	try {
		clickActor(globalObj, quickSettings);
	} catch (e) {
		smokeLog('miss threw ' + formatError(e));
		global.context.terminate();
		return;
	}
	later(1000, () => {
		smokeLog('after open ' + menuState(menu));
		if (!menu.isOpen || !menu.actor.visible) {
			smokeLog('miss did-not-open');
			global.context.terminate();
			return;
		}
		smokeLog(`outside click ${outsideX},${outsideY}`);
		globalObj.pointer_click(outsideX, outsideY);
		later(1000, () => {
			smokeLog('after outside ' + menuState(menu));
			const outsideHid = !menu.isOpen && !menu.actor.visible;
			smokeLog(outsideHid ? 'settings hid' : 'settings stayed');
			const afterButton = () => {
				if (!outsideHid) {
					smokeLog('after second button ' + menuState(menu));
				}
				const buttonHid = outsideHid || (!menu.isOpen && !menu.actor.visible);
				menu.close(0);
				later(600, () => {
					smokeLog('after close() ' + menuState(menu));
					const closeHid = !menu.actor.visible;
					let fault = '';
					if (!outsideHid)
						fault += ' outside';
					if (!buttonHid)
						fault += ' button';
					if (!closeHid)
						fault += ' close';
					if (fault.length > 0)
						smokeLog('settings stayed' + fault);
					else
						smokeLog('settings hid');
					scoreVolume(main, globalObj, menu, fault);
				});
			};
			if (outsideHid) {
				afterButton();
				return;
			}
			clickActor(globalObj, quickSettings);
			later(1000, afterButton);
		});
	});
}

/**
 * @param {object} main
 * @param {object} globalObj
 * @param {object} settingsMenu
 * @param {string} settingsFault
 */
function scoreVolume(main, globalObj, settingsMenu, settingsFault) {
	if (!settingsMenu.isOpen)
		settingsMenu.open(0);
	later(400, () => {
		const output = main.panel._volumeOutput
			? main.panel._volumeOutput._output : null;
		const volumeButton = output ? output._menuButton : null;
		if (!(output && output.menu && output.menuEnabled && volumeButton
				&& volumeButton.visible)) {
			smokeLog('volume button hidden');
			if (settingsFault.length > 0)
				smokeLog('miss' + settingsFault);
			else
				smokeLog('ok settings');
			global.context.terminate();
			return;
		}
		smokeLog('volume button ' + actorBox(volumeButton));
		clickActor(globalObj, volumeButton);
		later(1000, () => {
			smokeLog('after volume open ' + menuState(output.menu));
			if (!output.menu.isOpen || !output.menu.actor.visible) {
				smokeLog('miss' + settingsFault + ' volume-did-not-open');
				global.context.terminate();
				return;
			}
			clickActor(globalObj, volumeButton);
			later(1000, () => {
				smokeLog('after volume second click ' + menuState(output.menu));
				const volumeHid = !output.menu.isOpen && !output.menu.actor.visible;
				if (!volumeHid)
					settingsFault += ' volume';
				if (settingsFault.length > 0)
					smokeLog('miss' + settingsFault);
				else
					smokeLog('ok');
				global.context.terminate();
			});
		});
	});
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => {
				const deadline = GLib.get_monotonic_time()
					+ 20 * GLib.TIME_SPAN_SECOND;
				GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
					if ((main.panel == null || main.panel.statusArea == null
							|| main.panel.statusArea.quickSettings == null)
							&& GLib.get_monotonic_time() < deadline) {
						return GLib.SOURCE_CONTINUE;
					}
					runProve(main);
					return GLib.SOURCE_REMOVE;
				});
			});
		}).catch(e => {
			smokeLog('miss start ' + formatError(e));
			const error = new GLib.Error(
				Gio.IOErrorEnum, Gio.IOErrorEnum.FAILED, formatError(e));
			global.context.terminate_with_error(error);
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
