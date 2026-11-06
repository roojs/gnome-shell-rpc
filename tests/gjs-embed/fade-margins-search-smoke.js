/**
 * Overview search selects a result, then reads fade margins.
 *
 * Installed session: the user typed in the overview search. The shell
 * activated the Characters search provider and selected a result. Stock
 * {@code search.js} {@code _setSelected} calls
 * {@code ensureActorVisibleInScrollView}, which reads
 * {@code vfade.fade_margins.top}. That read is core 17562.
 *
 * Pass: {@code fade-margins-search/ui/init: ok}
 * Fail: {@code fade-margins-search/ui/init: miss <reason>}
 *
 * The {@code ui/init.js} path makes gsr-smoke take the shell startup
 * lock. Without it, mutter aborts during startup and this search never runs.
 *
 *   GSR_NESTED_TIMEOUT=60 GI_META_SMOKE=fade-margins-search/ui/init \
 *     ./scripts/agent-nested-smoke-prove.sh
 */

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'fade-margins-search/ui/init';
const SEARCH_TEXT = 'ter';
const WAIT_MS = 8000;

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
 * @param {object} main
 */
function runProve(main) {
	const entry = main.overview.searchEntry;
	const results = main.overview.searchController._searchResults;
	if (entry == null || results == null || results._scrollView == null) {
		finish('miss no-search');
		return;
	}

	let selected = false;
	const stockSetSelected = results._setSelected.bind(results);
	results._setSelected = (result, on) => {
		if (on && result != null)
			selected = true;
		return stockSetSelected(result, on);
	};

	/* Typing focuses the entry. key-focus-in sets highlightDefault, and
	 * the next selected result is what reads fade_margins. */
	entry.grab_key_focus();
	smokeLog('set clutter_text.text=' + SEARCH_TEXT);
	entry.clutter_text.text = SEARCH_TEXT;

	const deadline = GLib.get_monotonic_time() + WAIT_MS * 1000;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
		if (!selected && GLib.get_monotonic_time() < deadline)
			return GLib.SOURCE_CONTINUE;
		const text = entry.get_text();
		if (!selected) {
			finish('miss no-selection text=' + JSON.stringify(text));
			return GLib.SOURCE_REMOVE;
		}
		const vfade = results._scrollView.get_effect('fade');
		if (vfade == null) {
			finish('miss no-fade text=' + JSON.stringify(text));
			return GLib.SOURCE_REMOVE;
		}
		let top;
		try {
			top = vfade.fade_margins.top;
		} catch (e) {
			finish('miss read text=' + JSON.stringify(text)
				+ ' ' + formatError(e));
			return GLib.SOURCE_REMOVE;
		}
		smokeLog(
			'text=' + JSON.stringify(text)
			+ ' fade=' + (vfade.constructor ? vfade.constructor.name : typeof vfade)
			+ ' top=' + top
		);
		if (typeof top !== 'number' || !Number.isFinite(top)) {
			finish('miss top=' + top);
			return GLib.SOURCE_REMOVE;
		}
		finish('ok');
		return GLib.SOURCE_REMOVE;
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
