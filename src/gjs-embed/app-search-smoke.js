/**
 * 0.8 Search FAIL smoke — live miss: text fills, results list empty.
 *
 * Boots product {@code main.start}, sets the search entry text (bypass
 * Event / {@code fire_key}), then names the miss:
 * {@code AppSystem.search} / parental / {@code getInitialResultSet} /
 * {@code lookup_app} / {@code text-changed} / {@code setTerms} /
 * {@code getResultMetas} / IconGrid.
 *
 *   GSR_NESTED_TIMEOUT=40 GI_META_SMOKE=app-search-smoke \
 *     GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 *
 * Weston only. 🚫 vendor search.js.
 * See docs/bugs/2026-09-19-overview-app-search-empty.md
 */

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'app-search-smoke';
const SEARCH_WAIT_MS = 2000;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
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
 * @param {string[][]} groups
 * @returns {string}
 */
function firstHitId(groups) {
	if (groups == null)
		return '';
	for (let i = 0; i < groups.length; i++) {
		const g = groups[i];
		if (g != null && g.length > 0 && g[0])
			return String(g[0]);
	}
	return '';
}

/**
 * @param {object} main
 */
function runSearchProve(main) {
	const layout = main.layoutManager;
	const search = main.overview.searchController;
	const entry = main.overview.searchEntry;
	const resultsView = search._searchResults;
	const parental = resultsView._parentalControlsManager;

	smokeLog(
		'post-start startingUp=' + layout._startingUp
			+ ' overview.visible=' + main.overview.visible
			+ ' parental.initialized=' + (parental ? parental.initialized : 'n/a')
	);

	let nHits = 0;
	let hitId = '';
	let lookupOk = false;
	try {
		const groups = Shell.AppSystem.search('f');
		nHits = countHits(groups);
		hitId = firstHitId(groups);
		smokeLog('AppSystem.search(f) hits=' + nHits + ' first=' + JSON.stringify(hitId));
		if (hitId.length > 0) {
			try {
				const app = Shell.AppSystem.get_default().lookup_app(hitId);
				lookupOk = app != null;
				smokeLog(
					'lookup_app ok=' + lookupOk
						+ ' id=' + JSON.stringify(app ? app.get_id() : null)
						+ ' name=' + JSON.stringify(app ? app.get_name() : null)
				);
			} catch (e) {
				smokeLog('lookup_app threw ' + formatError(e));
			}
		}
	} catch (e) {
		smokeLog('FAIL AppSystem.search threw ' + formatError(e));
	}

	const providers = resultsView._providers || [];
	const appProv = providers.find(p => p.id === 'applications');
	let initialN = -1;
	let initialErr = '';
	let initialDone = false;
	if (appProv == null) {
		smokeLog('FAIL no applications provider');
		initialDone = true;
	} else {
		try {
			const p = appProv.getInitialResultSet(['f'], new Gio.Cancellable());
			p.then(ids => {
				initialDone = true;
				initialN = ids == null ? 0 : ids.length;
				smokeLog('getInitialResultSet n=' + initialN);
			}).catch(e => {
				initialDone = true;
				initialErr = formatError(e);
				smokeLog('getInitialResultSet threw ' + initialErr);
			});
		} catch (e) {
			initialDone = true;
			initialErr = formatError(e);
			smokeLog('getInitialResultSet sync-threw ' + initialErr);
		}
	}

	const ct = entry.clutter_text;
	let textChangedN = 0;
	ct.connect('text-changed', () => {
		textChangedN++;
	});
	smokeLog('set clutter_text.text=f');
	ct.text = 'f';

	GLib.timeout_add(GLib.PRIORITY_DEFAULT, SEARCH_WAIT_MS, () => {
		const searchActive = search.searchActive;
		const entryText = entry.text;
		const terms = resultsView.terms;
		const starting = resultsView._startingSearch;
		const inProgress = resultsView.searchInProgress;
		const status = resultsView._statusText ? resultsView._statusText.text : '';
		const defaultResult = resultsView._defaultResult;
		const appResults = resultsView._results ? resultsView._results.applications : null;
		const appN = appResults == null ? -1 : appResults.length;
		const display = appProv ? appProv.display : null;
		let first = null;
		let nGrid = -1;
		let displayVis = false;
		let displayMapped = false;
		if (display != null) {
			displayVis = display.visible;
			displayMapped = display.mapped;
			try {
				first = display.getFirstResult();
			} catch (e) {
				smokeLog('getFirstResult threw ' + formatError(e));
			}
			if (display._grid != null)
				nGrid = display._grid.get_n_children();
		}

		smokeLog(
			'after-text searchActive=' + searchActive
				+ ' textChangedN=' + textChangedN
				+ ' get_text=' + JSON.stringify(entry.get_text())
				+ ' entryText=' + JSON.stringify(entryText)
				+ ' terms=' + JSON.stringify(terms)
				+ ' startingSearch=' + starting
				+ ' searchInProgress=' + inProgress
				+ ' status=' + JSON.stringify(status)
				+ ' appResults=' + appN
				+ ' defaultResult=' + (defaultResult != null)
				+ ' displayVis=' + displayVis
				+ ' displayMapped=' + displayMapped
				+ ' nGrid=' + nGrid
				+ ' first=' + (first != null)
				+ ' initialDone=' + initialDone
				+ ' initialN=' + initialN
				+ ' parental.initialized=' + (parental ? parental.initialized : 'n/a')
		);

		let miss = '';
		if (nHits === 0)
			miss = 'AppSystem.search';
		else if (!initialDone)
			miss = parental && !parental.initialized ? 'parental' : 'getInitialResultSet';
		else if (initialErr.length > 0)
			miss = 'getInitialResultSet';
		else if (initialN === 0)
			miss = lookupOk ? 'getInitialResultSet' : 'lookup_app';
		else if (entryText !== 'f')
			miss = 'text-changed';
		else if (!searchActive)
			miss = 'text-changed';
		else if (!terms || terms.length === 0)
			miss = 'setTerms';
		else if (first == null && nGrid <= 0)
			miss = appN > 0 ? 'getResultMetas' : 'IconGrid';
		else if (first == null)
			miss = 'IconGrid';

		if (miss.length > 0)
			smokeLog('miss ' + miss);
		else
			smokeLog('ok');
		smokeLog('done');
		global.context.terminate();
		return GLib.SOURCE_REMOVE;
	});
}

imports._promiseNative.setMainLoopHook(() => {
	smokeLog('hook');
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		import('resource:///org/gnome/shell/ui/main.js').then(main => {
			return main.start().then(() => {
				runSearchProve(main);
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
