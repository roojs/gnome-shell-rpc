/**
 * 0.8 Search FAIL smoke — live miss: text fills, results list empty.
 *
 * Boots product {@code main.start}, sets the search entry text (bypass
 * Event / {@code fire_key}), then names the miss:
 * {@code AppSystem.search} / parental / {@code getInitialResultSet} /
 * {@code lookup_app} / {@code text-changed} / {@code setTerms} /
 * {@code getResultMetas} / {@code createResultObject} /
 * {@code second-updateSearch-clear} / {@code Searching} /
 * {@code empty-grid} / IconGrid.
 *
 * Live path: type ter (icons), wait, extra key term. No 1px allocate.
 * Named miss (observe 2026-09-22 09:47): first {@code updateSearch-out}
 * has {@code nGrid>0} {@code first=true} {@code width=792}; a second
 * out on the same terms leaves {@code nGrid=0} {@code first=false}
 * at the same width (stock catch: {@code remove_all_children}, no hide).
 *
 *   GSR_NESTED_TIMEOUT=60 GI_META_SMOKE=app-search-smoke \
 *     GSR_WESTON_MODE=prove ./scripts/weston-gsr-session.sh
 *
 * Weston only. 🚫 vendor search.js.
 * See docs/bugs/2026-09-19-overview-app-search-empty.md
 */

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Shell from 'gi://Shell';
import Clutter from 'gi://Clutter';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'app-search-smoke';
const SEARCH_WAIT_MS = 2000;
const WAIT_AFTER_ICONS_MS = 3000;
const FAST_AFTER_F_MS = 200;
const FAST_AFTER_FI_MS = 50;

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
			let app = null;
			try {
				app = Shell.AppSystem.get_default().lookup_app(hitId);
				lookupOk = app != null;
				smokeLog(
					'lookup_app ok=' + lookupOk
						+ ' id=' + JSON.stringify(app ? app.get_id() : null)
						+ ' name=' + JSON.stringify(app ? app.get_name() : null)
				);
			} catch (e) {
				smokeLog('lookup_app threw ' + formatError(e));
			}
			if (lookupOk && app != null) {
				try {
					const info = app.get_app_info();
					smokeLog(
						'get_app_info ok=' + (info != null)
							+ ' id=' + JSON.stringify(info ? info.get_id() : null)
					);
				} catch (e) {
					smokeLog('get_app_info threw ' + formatError(e));
				}
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
	let metasN = -1;
	let metasErr = '';
	let createErr = '';
	let createOk = false;
	let updateSearchErr = '';
	let allocateN = 0;
	let notifyN = 0;
	let maxZeroN = 0;
	let sawFill = false;
	let clearAfterFill = false;
	let ensureErr = '';
	let fadeMarginsErr = '';
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
				if (ids == null || ids.length === 0) {
					return;
				}
				return appProv.getResultMetas(ids.slice(0, 1)).then(metas => {
					metasN = metas == null ? 0 : metas.length;
					smokeLog('getResultMetas n=' + metasN);
					if (metasN < 1) {
						return;
					}
					try {
						const obj = appProv.createResultObject(metas[0]);
						createOk = obj != null;
						smokeLog(
							'createResultObject ok=' + createOk
								+ ' type=' + (obj ? obj.constructor.name : 'null')
						);
					} catch (e) {
						createErr = formatError(e);
						smokeLog('createResultObject threw ' + createErr);
					}
				}).catch(e => {
					metasErr = formatError(e);
					smokeLog('getResultMetas threw ' + metasErr);
				});
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
	if (appProv != null && appProv.display != null) {
		const display = appProv.display;
		const baseProto = Object.getPrototypeOf(Object.getPrototypeOf(display));
		const origBase = baseProto.updateSearch;
		baseProto.updateSearch = function (...args) {
			try {
				const ret = origBase.apply(this, args);
				if (ret != null && typeof ret.then === 'function') {
					ret.catch(e => {
						updateSearchErr = formatError(e);
						smokeLog('updateSearch threw ' + updateSearchErr);
					});
				}
				return ret;
			} catch (e) {
				updateSearchErr = formatError(e);
				smokeLog('updateSearch sync-threw ' + updateSearchErr);
				throw e;
			}
		};
		const origEnsure = display._ensureResultActors.bind(display);
		display._ensureResultActors = async function (results) {
			try {
				return await origEnsure(results);
			} catch (e) {
				ensureErr = formatError(e);
				smokeLog('_ensureResultActors threw ' + ensureErr);
				throw e;
			}
		};
		const origClear = display._clearResultDisplay.bind(display);
		display._clearResultDisplay = function () {
			let n = display._grid ? display._grid.get_n_children() : -1;
			smokeLog('clear nGrid=' + n + ' vis=' + display.visible);
			return origClear();
		};
		const origAdd = display._addItem.bind(display);
		display._addItem = function (item) {
			try {
				return origAdd(item);
			} catch (e) {
				ensureErr = formatError(e);
				smokeLog('_addItem threw ' + ensureErr);
				throw e;
			}
		};
		const origGridUpdate = display.updateSearch.bind(display);
		display.updateSearch = function (results, terms, callback) {
			let nGrid = display._grid ? display._grid.get_n_children() : -1;
			smokeLog(
				'updateSearch-in terms=' + JSON.stringify(terms)
					+ ' results=' + (results == null ? -1 : results.length)
					+ ' nGrid=' + nGrid
			);
			return origGridUpdate(results, terms, function () {
				let first = null;
				try {
					first = display.getFirstResult();
				} catch (e) {
					smokeLog('getFirstResult ' + formatError(e));
				}
				nGrid = display._grid ? display._grid.get_n_children() : -1;
				let width = 'n/a';
				try {
					width = String(display.allocation.get_width());
				} catch (e) {
					width = 'err:' + formatError(e);
				}
				smokeLog(
					'updateSearch-out terms=' + JSON.stringify(terms)
						+ ' nGrid=' + nGrid
						+ ' first=' + (first != null)
						+ ' vis=' + display.visible
						+ ' width=' + width
				);
				if (nGrid > 0 && first != null)
					sawFill = true;
				else if (sawFill && nGrid <= 0)
					clearAfterFill = true;
				if (!callback)
					return;
				try {
					callback();
				} catch (e) {
					const text = formatError(e);
					smokeLog('updateSearch-callback threw ' + text);
					if (text.indexOf('fade_margins') >= 0)
						fadeMarginsErr = text;
					throw e;
				}
			});
		};
		const origMax = display._getMaxDisplayedResults.bind(display);
		display._getMaxDisplayedResults = function () {
			let width = 'n/a';
			let mutter = 'n/a';
			try {
				width = String(this.allocation.get_width());
			} catch (e) {
				width = 'err:' + formatError(e);
			}
			try {
				mutter = String(this.get_allocation_box().get_width());
			} catch (e) {
				mutter = 'err:' + formatError(e);
			}
			let n = -1;
			try {
				n = origMax();
			} catch (e) {
				smokeLog('_getMaxDisplayedResults width=' + width
					+ ' mutter=' + mutter + ' threw ' + formatError(e));
				throw e;
			}
			smokeLog('_getMaxDisplayedResults width=' + width
				+ ' mutter=' + mutter + ' n=' + n);
			if (n === 0 && Number(width) !== 0)
				maxZeroN++;
			return n;
		};
		const origAllocate = display.allocate.bind(display);
		display.allocate = function (box, flags) {
			allocateN++;
			let w = 'n/a';
			try {
				w = String(box.get_width());
			} catch (e) {
				w = 'err:' + formatError(e);
			}
			smokeLog('display.allocate n=' + allocateN + ' w=' + w);
			if (flags === undefined)
				return origAllocate(box);
			return origAllocate(box, flags);
		};
		display.connect('notify::allocation', () => {
			notifyN++;
			let w = 'n/a';
			try {
				w = String(display.allocation.get_width());
			} catch (e) {
				w = 'err:' + formatError(e);
			}
			smokeLog('notify::allocation w=' + w);
		});
	}
	let textChangedN = 0;
	ct.connect('text-changed', () => {
		textChangedN++;
	});

	/**
	 * Last GJS allocate() box vs mutter get_allocation_box.
	 *
	 * @param {object | null} actor
	 * @returns {string}
	 */
	function boxLine(actor) {
		if (actor == null)
			return 'null';
		let cache = 'n/a';
		let mutter = 'n/a';
		let w = 'n/a';
		try {
			cache = String(actor.allocation.get_width());
		} catch (e) {
			cache = 'err:' + formatError(e);
		}
		try {
			mutter = String(actor.get_allocation_box().get_width());
		} catch (e) {
			mutter = 'err:' + formatError(e);
		}
		try {
			w = String(actor.get_width());
		} catch (e) {
			w = 'err:' + formatError(e);
		}
		return 'cache=' + cache + ' mutter=' + mutter + ' get_width=' + w;
	}

	/**
	 * @param {string} tag
	 * @param {string} wantText
	 * @returns {string}
	 */
	function snapshot(tag, wantText) {
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
		let allocW = 'n/a';
		let mutterW = 'n/a';
		let actorW = 'n/a';
		let nCols = 'n/a';
		let minW = 'n/a';
		let statusBinVis = false;
		let scrollVis = false;
		let displayBox = 'n/a';
		let parentBox = 'n/a';
		let scrollBox = 'n/a';
		if (resultsView._statusBin)
			statusBinVis = resultsView._statusBin.visible;
		const providersInFlight = (resultsView._providers || []).map(p => {
			let extra = '';
			if (p.proxy) {
				try {
					extra = ' owner=' + JSON.stringify(p.proxy.g_name_owner)
						+ ' timeout=' + p.proxy.g_default_timeout;
				} catch (e) {
					extra = ' proxy=' + formatError(e);
				}
			}
			return String(p.id) + ':' + !!p.searchInProgress + extra;
		}).join(',');
		let fadeKind = 'n/a';
		let fadeMargins = 'n/a';
		if (resultsView._scrollView) {
			scrollVis = resultsView._scrollView.visible;
			scrollBox = boxLine(resultsView._scrollView);
			try {
				const vfade = resultsView._scrollView.get_effect('fade');
				if (vfade == null) {
					fadeKind = 'null';
				} else {
					fadeKind = vfade.constructor ? vfade.constructor.name : typeof vfade;
					try {
						fadeMargins = vfade.fade_margins == null
							? 'undefined'
							: String(vfade.fade_margins.top);
					} catch (e2) {
						fadeMargins = 'err:' + formatError(e2);
						if (fadeMarginsErr.length === 0)
							fadeMarginsErr = formatError(e2);
					}
					if (vfade.fade_margins == null && fadeMarginsErr.length === 0)
						fadeMarginsErr = 'vfade.fade_margins is undefined';
				}
			} catch (e) {
				fadeKind = 'err:' + formatError(e);
			}
		}
		if (display != null) {
			displayVis = display.visible;
			displayMapped = display.mapped;
			displayBox = boxLine(display);
			try {
				parentBox = boxLine(display.get_parent());
			} catch (e) {
				parentBox = 'err:' + formatError(e);
			}
			try {
				first = display.getFirstResult();
			} catch (e) {
				smokeLog('getFirstResult threw ' + formatError(e));
			}
			if (display._grid != null)
				nGrid = display._grid.get_n_children();
			try {
				allocW = String(display.allocation.get_width());
			} catch (e) {
				allocW = 'err:' + formatError(e);
			}
			try {
				mutterW = String(display.get_allocation_box().get_width());
			} catch (e) {
				mutterW = 'err:' + formatError(e);
			}
			try {
				actorW = String(display.get_width());
			} catch (e) {
				actorW = 'err:' + formatError(e);
			}
			try {
				if (display._grid != null && display._grid.layout_manager != null) {
					const lm = display._grid.layout_manager;
					const width = Number(allocW);
					if (Number.isFinite(width))
						nCols = String(lm.columnsForWidth(width));
					try {
						const pref = lm.get_preferred_width(display._grid, -1);
						minW = String(pref[0]) + '/' + String(pref[1])
							+ ' c1=' + lm.columnsForWidth(1)
							+ ' c1280=' + lm.columnsForWidth(1280);
					} catch (e2) {
						minW = 'err:' + formatError(e2);
					}
				}
			} catch (e) {
				nCols = 'err:' + formatError(e);
			}
		}

		smokeLog(
			tag + ' searchActive=' + searchActive
				+ ' overview.visible=' + main.overview.visible
				+ ' textChangedN=' + textChangedN
				+ ' get_text=' + JSON.stringify(entry.get_text())
				+ ' entryText=' + JSON.stringify(entryText)
				+ ' terms=' + JSON.stringify(terms)
				+ ' startingSearch=' + starting
				+ ' searchInProgress=' + inProgress
				+ ' status=' + JSON.stringify(status)
				+ ' statusBin=' + statusBinVis
				+ ' scroll=' + scrollVis
				+ ' appResults=' + appN
				+ ' defaultResult=' + (defaultResult != null)
				+ ' displayVis=' + displayVis
				+ ' displayMapped=' + displayMapped
				+ ' nGrid=' + nGrid
				+ ' first=' + (first != null)
				+ ' allocW=' + allocW
				+ ' mutterW=' + mutterW
				+ ' actorW=' + actorW
				+ ' allocateN=' + allocateN
				+ ' notifyN=' + notifyN
				+ ' providers=' + providersInFlight
				+ ' displayBox=' + displayBox
				+ ' parentBox=' + parentBox
				+ ' scrollBox=' + scrollBox
				+ ' nCols=' + nCols
				+ ' minW=' + minW
				+ ' initialDone=' + initialDone
				+ ' initialN=' + initialN
				+ ' metasN=' + metasN
				+ ' createOk=' + createOk
				+ ' updateSearchErr=' + JSON.stringify(updateSearchErr)
				+ ' ensureErr=' + JSON.stringify(ensureErr)
				+ ' sawFill=' + sawFill
				+ ' clearAfterFill=' + clearAfterFill
				+ ' fade=' + fadeKind
				+ ' fadeMargins=' + fadeMargins
				+ ' fadeMarginsErr=' + JSON.stringify(fadeMarginsErr)
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
		else if (metasErr.length > 0)
			miss = 'getResultMetas';
		else if (createErr.length > 0)
			miss = 'createResultObject';
		else if (updateSearchErr.length > 0)
			miss = 'updateSearch';
		else if (fadeMarginsErr.length > 0)
			miss = 'fade-margins';
		else if (clearAfterFill)
			miss = 'second-updateSearch-clear';
		else if (entryText !== wantText)
			miss = 'text-changed';
		else if (!terms || terms.length === 0)
			miss = 'setTerms';
		else if (statusBinVis && (starting || inProgress))
			miss = 'Searching';
		else if (maxZeroN > 0)
			miss = 'maxResults-zero';
		else if (Number(allocW) === 0
				&& Number.isFinite(Number(mutterW))
				&& Number(mutterW) > 0)
			miss = 'allocation-cache-zero';
		else if (first == null && nGrid <= 0) {
			if (inProgress || status.indexOf('Searching') >= 0 || statusBinVis)
				miss = 'Searching';
			else if (appN > 0)
				miss = createOk ? 'empty-grid' : 'getResultMetas';
			else
				miss = 'IconGrid';
		} else if (statusBinVis)
			miss = 'Searching';
		else if (first == null)
			miss = 'IconGrid';
		return miss;
	}

	function finish(miss) {
		if (miss.length > 0)
			smokeLog('miss ' + miss);
		else
			smokeLog('ok');
		smokeLog('done');
		global.context.terminate();
	}

	const readyDeadline = GLib.get_monotonic_time() + 25 * GLib.TIME_SPAN_SECOND;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
		if (!main.overview.visible
				&& GLib.get_monotonic_time() < readyDeadline)
			return GLib.SOURCE_CONTINUE;
		smokeLog(
			'ready startingUp=' + layout._startingUp
				+ ' overview.visible=' + main.overview.visible
		);
		entry.grab_key_focus();
		smokeLog('set clutter_text.text=ter');
		ct.text = 'ter';
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, SEARCH_WAIT_MS, () => {
			const missTer = snapshot('after-ter', 'ter');
			if (missTer.length > 0) {
				finish(missTer);
				return GLib.SOURCE_REMOVE;
			}
			GLib.timeout_add(GLib.PRIORITY_DEFAULT, WAIT_AFTER_ICONS_MS, () => {
				const missWait = snapshot('after-wait', 'ter');
				if (missWait.length > 0) {
					finish(missWait);
					return GLib.SOURCE_REMOVE;
				}
				updateSearchErr = '';
				smokeLog('set clutter_text.text=term');
				ct.text = 'term';
				GLib.timeout_add(GLib.PRIORITY_DEFAULT, SEARCH_WAIT_MS, () => {
					finish(snapshot('after-term', 'term'));
					return GLib.SOURCE_REMOVE;
				});
				return GLib.SOURCE_REMOVE;
			});
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
