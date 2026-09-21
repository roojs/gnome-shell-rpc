/**
 * Clock click regression — date menu open must not crash.
 *
 *   GSR_NESTED_TIMEOUT=40 GI_META_SMOKE=date-menu-open-smoke \
 *     GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 *
 * See docs/bugs/2026-09-16-chrome-panel-menus-overlay.md
 */

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'date-menu-open-smoke';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

/**
 * @param {object} main
 */
function runProve(main) {
	const dateMenu = main.panel.statusArea.dateMenu;
	if (dateMenu == null || dateMenu.menu == null) {
		smokeLog('FAIL no-dateMenu');
		global.context.terminate();
		return;
	}
	smokeLog('open dateMenu');
	try {
		dateMenu.menu.open(0);
	} catch (e) {
		smokeLog('FAIL open-threw ' + formatError(e));
		global.context.terminate();
		return;
	}
	if (!dateMenu.menu.isOpen) {
		smokeLog('FAIL not-open');
		global.context.terminate();
		return;
	}
	smokeLog('ok');
	global.context.terminate();
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
							|| main.panel.statusArea.dateMenu == null)
							&& GLib.get_monotonic_time() < deadline) {
						return GLib.SOURCE_CONTINUE;
					}
					runProve(main);
					return GLib.SOURCE_REMOVE;
				});
			});
		}).catch(e => {
			smokeLog('FAIL start ' + formatError(e));
			const error = new GLib.Error(
				Gio.IOErrorEnum, Gio.IOErrorEnum.FAILED, formatError(e));
			global.context.terminate_with_error(error);
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
