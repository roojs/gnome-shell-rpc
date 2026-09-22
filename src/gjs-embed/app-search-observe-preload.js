/**
 * Observe-only hook for the held session. Does not type, allocate, or
 * change search behavior. Logs the stock second-updateSearch inputs
 * the live RPC log already showed: fill, then a later clear.
 *
 *   GI_RPC_GJS_EMBED_DIR=src/gjs-embed \
 *   GI_RPC_REGISTER_CLASS_TRACE=1 \
 *   GI_RPC_APP_SEARCH_OBSERVE=1 \
 *     GSR_WESTON_MODE=session ./scripts/weston-gsr-session.sh
 */
import GLib from 'gi://GLib';

const TAG = 'app-search-observe';

function observeLog(message) {
	log(TAG + ': ' + message);
}

function errText(e) {
	return e && e.message ? e.message : String(e);
}

function widthOf(actor) {
	if (actor == null)
		return 'n/a';
	try {
		return String(actor.allocation.get_width());
	} catch (e) {
		return 'err:' + errText(e);
	}
}

function mutterWidthOf(actor) {
	if (actor == null)
		return 'n/a';
	try {
		return String(actor.get_allocation_box().get_width());
	} catch (e) {
		return 'err:' + errText(e);
	}
}

function install(main) {
	const resultsView = main.overview.searchController._searchResults;
	const providers = resultsView._providers || [];
	const appProv = providers.find(p => p.id === 'applications');
	if (appProv == null || appProv.display == null) {
		observeLog('no applications display');
		return;
	}

	const display = appProv.display;
	const origMax = display._getMaxDisplayedResults.bind(display);
	display._getMaxDisplayedResults = function () {
		const width = widthOf(this);
		const mutter = mutterWidthOf(this);
		let n = origMax();
		observeLog('_getMaxDisplayedResults width=' + width
			+ ' mutter=' + mutter + ' n=' + n);
		return n;
	};

	function wrapThrow(name, fn) {
		return function (...args) {
			try {
				return fn.apply(this, args);
			} catch (e) {
				observeLog(name + ' threw ' + errText(e));
				throw e;
			}
		};
	}

	const origEnsure = display._ensureResultActors.bind(display);
	display._ensureResultActors = async function (results) {
		try {
			return await origEnsure(results);
		} catch (e) {
			observeLog('_ensureResultActors threw ' + errText(e)
				+ ' n=' + (results == null ? -1 : results.length));
			throw e;
		}
	};

	display.hide = wrapThrow('hide', display.hide.bind(display));
	display.show = wrapThrow('show', display.show.bind(display));
	display._addItem = wrapThrow('_addItem', display._addItem.bind(display));
	display._setMoreCount = wrapThrow(
		'_setMoreCount', display._setMoreCount.bind(display));

	const origClear = display._clearResultDisplay.bind(display);
	display._clearResultDisplay = function () {
		let nGrid = display._grid ? display._grid.get_n_children() : -1;
		let stack = '';
		try {
			stack = new Error().stack.split('\n').slice(1, 7).join(' || ');
		} catch (e) {
			stack = errText(e);
		}
		observeLog('clear nGrid=' + nGrid
			+ ' vis=' + display.visible
			+ ' width=' + widthOf(display)
			+ ' stack=' + stack);
		try {
			return origClear();
		} catch (e) {
			observeLog('_clearResultDisplay threw ' + errText(e));
			throw e;
		}
	};

	if (appProv.getResultMetas) {
		const origMetas = appProv.getResultMetas.bind(appProv);
		appProv.getResultMetas = function (ids, cancellable) {
			observeLog('getResultMetas n=' + (ids == null ? -1 : ids.length));
			try {
				const ret = origMetas(ids, cancellable);
				if (ret != null && typeof ret.then === 'function') {
					return ret.catch(e => {
						observeLog('getResultMetas threw ' + errText(e));
						throw e;
					});
				}
				return ret;
			} catch (e) {
				observeLog('getResultMetas sync-threw ' + errText(e));
				throw e;
			}
		};
	}

	const origUpdate = display.updateSearch.bind(display);
	display.updateSearch = function (results, terms, callback) {
		let nGrid = display._grid ? display._grid.get_n_children() : -1;
		observeLog('updateSearch-in terms=' + JSON.stringify(terms)
			+ ' results=' + (results == null ? -1 : results.length)
			+ ' nGrid=' + nGrid
			+ ' width=' + widthOf(display));
		return origUpdate(results, terms, function () {
			let first = null;
			try {
				first = display.getFirstResult();
			} catch (e) {
				observeLog('getFirstResult ' + errText(e));
			}
			nGrid = display._grid ? display._grid.get_n_children() : -1;
			observeLog('updateSearch-out terms=' + JSON.stringify(terms)
				+ ' nGrid=' + nGrid
				+ ' first=' + (first != null)
				+ ' vis=' + display.visible
				+ ' width=' + widthOf(display));
			if (!callback)
				return;
			try {
				callback();
			} catch (e) {
				observeLog('updateSearch-callback threw ' + errText(e));
				throw e;
			}
		});
	};

	const origProgress = resultsView._updateSearchProgress.bind(resultsView);
	resultsView._updateSearchProgress = function () {
		origProgress();
		let first = null;
		let nGrid = -1;
		try {
			first = display.getFirstResult();
		} catch (e) {
			observeLog('getFirstResult ' + errText(e));
		}
		if (display._grid != null)
			nGrid = display._grid.get_n_children();
		const status = resultsView._statusText ? resultsView._statusText.text : '';
		observeLog('progress terms=' + JSON.stringify(resultsView.terms)
			+ ' starting=' + resultsView._startingSearch
			+ ' inProgress=' + resultsView.searchInProgress
			+ ' status=' + JSON.stringify(status)
			+ ' statusBin=' + !!(resultsView._statusBin && resultsView._statusBin.visible)
			+ ' nGrid=' + nGrid
			+ ' first=' + (first != null)
			+ ' width=' + widthOf(display));
	};

	observeLog('installed');
}

GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
	import('resource:///org/gnome/shell/ui/main.js').then(main => {
		if (main.overview && main.overview.searchController) {
			install(main);
			return;
		}
		GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
			if (!main.overview || !main.overview.searchController)
				return GLib.SOURCE_CONTINUE;
			install(main);
			return GLib.SOURCE_REMOVE;
		});
	}).catch(e => {
		observeLog('FAIL ' + errText(e));
	});
	return GLib.SOURCE_REMOVE;
});
