/**
 * Overview search inserts the first letter twice.
 *
 * Pass: `overview-search-double-key: ok` (first letter once, second once)
 * Fail: `overview-search-double-key: miss <reason>`
 *
 *   GSR_WESTON_PIXMAN=1 GSR_NESTED_TIMEOUT=60 \
 *     GI_META_SMOKE=overview-search-double-key \
 *     ./scripts/agent-nested-smoke-prove.sh
 */

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'overview-search-double-key';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

/**
 * @param {string} message
 */
function finish(message) {
	smokeLog(message);
	global.context.terminate();
}

/**
 * Virtual key delivery re-enters the client. Read the entry after that
 * returns to the main loop.
 *
 * @param {number} ms
 */
function waitMs(ms) {
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

/**
 * @param {object} main
 */
function runProve(main) {
	const entry = main.overview.searchEntry;
	if (entry == null) {
		finish('miss no-entry');
		return;
	}
	const search = main.overview.searchController;
	search.reset();
	global.stage.set_key_focus(null);
	const before = entry.get_text();
	Shell.Global.get().fire_key(Clutter.KEY_t, 0);
	waitMs(200);
	const first = entry.clutter_text.get_text();
	const focus = global.stage.get_key_focus();
	smokeLog(
		'before=' + JSON.stringify(before)
		+ ' first=' + JSON.stringify(first)
		+ ' focus=' + (focus ? focus.name : 'null')
		+ ' modal=' + main.modalCount
		+ ' visible=' + main.overview.visible
	);
	if (first === 'tt') {
		finish('miss doubled');
		return;
	}
	if (first !== 't') {
		finish('miss first=' + JSON.stringify(first));
		return;
	}
	Shell.Global.get().fire_key(Clutter.KEY_e, 0);
	waitMs(200);
	const second = entry.clutter_text.get_text();
	smokeLog('second=' + JSON.stringify(second));
	if (second !== 'te') {
		finish('miss second=' + JSON.stringify(second));
		return;
	}
	finish('ok');
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(async main => {
			const PanelMenu =
				await import('resource:///org/gnome/shell/ui/panelMenu.js');
			const setMenu = PanelMenu.Button.prototype.setMenu;
			PanelMenu.Button.prototype.setMenu = function (menu) {
				if (menu)
					menu.actor.hide();
				return setMenu.call(this, menu);
			};
			return main.start().then(() => {
				const deadline = GLib.get_monotonic_time()
					+ 20 * GLib.TIME_SPAN_SECOND;
				GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
					if (!main.overview.visible
							&& GLib.get_monotonic_time() < deadline) {
						main.overview.show();
						return GLib.SOURCE_CONTINUE;
					}
					if (!main.overview.visible) {
						finish('miss overview-hidden');
						return GLib.SOURCE_REMOVE;
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
