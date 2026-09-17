/**
 * 0.8 Search FAIL smoke — printable key with overview shown.
 *
 * Boots product {@code main.start} (not a GI_META_SMOKE that skips init),
 * {@code overview.show()}, injects {@code KEY_f}, then names the miss:
 * {@code AppSystem.search} / Event / {@code Clutter.Text} / results-layout.
 *
 *   GSR_NESTED_TIMEOUT=40 GI_META_SMOKE=app-search-smoke \
 *     GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 *
 * Weston only. 🚫 vendor search.js.
 */

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Clutter from 'gi://Clutter';
import Shell from 'gi://Shell';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'app-search-smoke';

/**
 * @param {string} message
 */
function smokeLog(message) {
	console.log(SMOKE + ': ' + message);
}

/**
 * @param {string[][]} groups
 * @returns {number}
 */
function countHits(groups) {
	let n = 0;
	if (groups == null)
		return 0;
	for (let i = 0; i < groups.length; i++) {
		const g = groups[i];
		if (g != null)
			n += g.length;
	}
	return n;
}

/**
 * @param {object} main
 */
function runSearchProve(main) {
	const globalObj = Shell.Global.get();
	const layout = main.layoutManager;
	smokeLog(
		'post-start startingUp=' + layout._startingUp
			+ ' overview.visible=' + main.overview.visible
	);

	/* show() during _startingUp hits _syncGrab too early (stock
	 * runStartupAnimation defers the grab) and never returns. */

	smokeLog(
		'overview visible=' + main.overview.visible
			+ ' animation=' + main.overview.animationInProgress
			+ ' modalCount=' + main.modalCount
	);

	let nHits = 0;
	try {
		const groups = Shell.AppSystem.search('f');
		nHits = countHits(groups);
		smokeLog('AppSystem.search(f) hits=' + nHits);
	} catch (e) {
		smokeLog('FAIL AppSystem.search threw ' + formatError(e));
	}

	const search = main.overview.searchController;
	const entry = main.overview.searchEntry;
	const stage = globalObj.get_stage();

	let sawPress = 0;
	let lastSymbol = -1;
	const pressId = stage.connect('key-press-event', (actor, event) => {
		sawPress++;
		try {
			lastSymbol = event.get_key_symbol();
		} catch (e) {
			lastSymbol = -2;
			smokeLog('get_key_symbol threw ' + formatError(e));
		}
		smokeLog('key-press-event n=' + sawPress + ' symbol=' + lastSymbol);
		return Clutter.EVENT_PROPAGATE;
	});

	const unicodeKind = typeof Clutter.keysym_to_unicode;
	let unicode = -1;
	smokeLog('keysym_to_unicode typeof=' + unicodeKind);
	if (unicodeKind === 'function') {
		try {
			unicode = Clutter.keysym_to_unicode(Clutter.KEY_f);
		} catch (e) {
			smokeLog('keysym_to_unicode threw ' + formatError(e));
		}
	}
	smokeLog('KEY_f=' + Clutter.KEY_f + ' unicode=' + unicode);

	smokeLog('fire_key KEY_f');
	globalObj.fire_key(Clutter.KEY_f, 0);
	smokeLog('fire_key returned');

	GLib.timeout_add(GLib.PRIORITY_HIGH, 50, () => {
		stage.disconnect(pressId);

		const searchActive = search.searchActive;
		const entryText = entry.text;
		const results = search._searchResults;
		let resultsVis = false;
		let resultsMapped = false;
		if (results != null) {
			resultsVis = results.visible;
			resultsMapped = results.mapped;
		}
		smokeLog(
			'after-key searchActive=' + searchActive
				+ ' entryText=' + JSON.stringify(entryText)
				+ ' resultsVis=' + resultsVis
				+ ' resultsMapped=' + resultsMapped
				+ ' sawPress=' + sawPress
				+ ' lastSymbol=' + lastSymbol
				+ ' overview.visible=' + main.overview.visible
		);

		let miss = '';
		if (nHits === 0)
			miss = 'AppSystem.search';
		else if (sawPress === 0)
			miss = 'Event';
		else if (lastSymbol !== Clutter.KEY_f)
			miss = 'Event';
		else if (unicodeKind !== 'function' || unicode === 0)
			miss = 'Event';
		else if (!main.overview.visible)
			miss = 'overview';
		else if (!searchActive)
			miss = 'Clutter.Text';
		else if (!resultsVis && !resultsMapped)
			miss = 'results-layout';

		if (miss.length > 0)
			smokeLog('miss ' + miss);
		else
			smokeLog('ok');
		global.context.terminate();
		return GLib.SOURCE_REMOVE;
	});
}

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => {
				runSearchProve(main);
			});
		}).catch(e => {
			const error = new GLib.Error(
				Gio.IOErrorEnum, Gio.IOErrorEnum.FAILED, formatError(e));
			global.context.terminate_with_error(error);
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
