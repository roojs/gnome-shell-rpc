/**
 * A panel click must leave the menu open. The opening press used to
 * run vfunc_event twice, so PanelMenu toggled shut before the click
 * returned.
 *
 *   GI_META_SMOKE=panel-menu-stay-smoke ./scripts/weston-gsr-prove.sh
 */
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'panel-menu-stay-smoke';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

/**
 * Virtual pointer absolute motion lands short of the stage point.
 * The 08:50 slider click asked 140,60 and the window event was 102,1.
 *
 * @param {object} globalObj
 * @param {object} actor
 */
function clickActor(globalObj, actor) {
	const [x, y] = actor.get_transformed_position();
	const cx = x + actor.width / 2 + 38;
	const cy = y + actor.height / 2 + 59;
	smokeLog(`click ${actor} at ${cx},${cy} size=${actor.width}x${actor.height}`);
	globalObj.pointer_click(cx, cy);
}

/**
 * @param {object} main
 */
function runProve(main) {
	const globalObj = global;
	const dateMenu = main.panel.statusArea.dateMenu;
	const quickSettings = main.panel.statusArea.quickSettings;
	if (dateMenu == null || dateMenu.menu == null
			|| quickSettings == null || quickSettings.menu == null) {
		smokeLog('miss no-menu');
		global.context.terminate();
		return;
	}
	const later = (ms, fn) => {
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
			try {
				fn();
			} catch (e) {
				smokeLog('miss threw ' + formatError(e));
				global.context.terminate();
			}
			return GLib.SOURCE_REMOVE;
		});
	};
	try {
		clickActor(globalObj, dateMenu);
	} catch (e) {
		smokeLog('miss threw ' + formatError(e));
		global.context.terminate();
		return;
	}
	later(1200, () => {
		if (!dateMenu.menu.isOpen) {
			smokeLog('miss date-closed');
			global.context.terminate();
			return;
		}
		smokeLog('date open');
		dateMenu.menu.close(0);
		clickActor(globalObj, quickSettings);
		later(1200, () => {
			if (!quickSettings.menu.isOpen) {
				smokeLog('miss quick-settings-closed');
				global.context.terminate();
				return;
			}
			smokeLog('quick-settings open');
			const output = main.panel._volumeOutput
				? main.panel._volumeOutput._output : null;
			const volumeButton = output ? output._menuButton : null;
			if (!(output && output.menuEnabled && volumeButton
					&& volumeButton.visible)) {
				smokeLog('volume button hidden');
				smokeLog('ok');
				global.context.terminate();
				return;
			}
			clickActor(globalObj, volumeButton);
			later(1200, () => {
				if (!output.menu.isOpen) {
					smokeLog('miss volume-closed');
					global.context.terminate();
					return;
				}
				smokeLog('volume open');
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
					+ 25 * GLib.TIME_SPAN_SECOND;
				GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
					if ((main.panel == null || main.panel.statusArea == null
							|| main.panel.statusArea.dateMenu == null
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
