/**
 * The volume arrow and the power button must sit above the list they
 * open, not on it. QuickToggleMenu binds its Y to the source and sets
 * the constraint offset from the source height.
 *
 *   GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh
 */
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Graphene from 'gi://Graphene';
import St from 'gi://St';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'menu-expander-overlap/ui/init';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

/**
 * Parent-relative allocation, then the same sum walked to the stage.
 * A missing stage transform was NaN and compared as "no overlap".
 *
 * @param {object} actor
 */
function place(actor) {
	const box = actor.get_allocation_box();
	let x = 0;
	let y = 0;
	let current = actor;
	const chain = [];
	while (current != null) {
		const step = current.get_allocation_box();
		const w = step.x2 - step.x1;
		const h = step.y2 - step.y1;
		chain.push(`${step.x1},${step.y1} ${w}x${h}`);
		x += step.x1;
		y += step.y1;
		current = current.get_parent();
	}
	return {
		x,
		y,
		w: box.x2 - box.x1,
		h: box.y2 - box.y1,
		chain: chain.join(' / '),
	};
}

/**
 * @param {string} label
 * @param {object} source
 * @param {object} menu
 */
function report(label, source, menu) {
	const s = place(source);
	const m = place(menu.actor);
	const [, nat] = menu.actor.get_preferred_height(-1);
	const gap = m.y - (s.y + s.h);
	const finite = [s.y, s.h, m.x, m.y, m.w, m.h].every(Number.isFinite);
	const own = menu.actor.get_allocation_box();
	const sourceHeight = source.height;
	/* The list belongs at or below the control. A negative gap means
	 * the list starts on the control. When the control's box is not
	 * finite, the list's own Y is the constraint offset: it should be
	 * the control's height, not 0. */
	const gapHigh = finite && gap < -2;
	const unpushed = !finite
		&& Number.isFinite(sourceHeight) && sourceHeight > 2
		&& Number.isFinite(own.y1) && own.y1 + 2 < sourceHeight;
	const high = gapHigh || unpushed;
	smokeLog(`${label} source=${s.x},${s.y} ${s.w}x${s.h}`
		+ ` menu=${m.x},${m.y} ${m.w}x${m.h}`
		+ ` nat=${nat} gap=${gap} height=${sourceHeight} menuY=${own.y1}`
		+ ` open=${menu.isOpen} finite=${finite} high=${high}`);
	smokeLog(`${label} source-chain ${s.chain}`);
	smokeLog(`${label} menu-chain ${m.chain}`);
	return high;
}

/**
 * @param {object} main
 */
/**
 * An empty QuickSettingsLayout reports (0 - 1) * row_spacing = -12 and
 * mutter aborts on open. One visible row keeps that allocate alive.
 *
 * @param {object} menu
 */
function ensureGridRow(menu) {
	const grid = menu._grid;
	if (grid == null)
		return;
	let visible = 0;
	for (const child of grid) {
		if (child.visible)
			visible++;
	}
	if (visible > 0)
		return;
	grid.add_child(new St.Widget({width: 40, height: 40}));
	smokeLog('added grid row');
}

/**
 * @param {object} grid
 */
function logMenus(grid) {
	if (grid == null)
		return;
	for (const child of grid) {
		const item = child.menu != null ? child : child._delegate;
		if (item == null || item.menu == null)
			continue;
		const title = item.title ?? '';
		const access = child.accessible_name ?? '';
		smokeLog(`submenu style=${child.style_class} visible=${child.visible}`
			+ ` title=${title} access=${access} menuEnabled=${item.menuEnabled}`);
	}
}

/**
 * @param {object} grid
 * @returns {Array<{label: string, item: object}>}
 */
function visibleMenus(grid) {
	const rows = [];
	if (grid == null)
		return rows;
	for (const child of grid) {
		const item = child.menu != null ? child : child._delegate;
		if (item == null || item.menu == null || !child.visible)
			continue;
		const title = item.title ?? '';
		const access = child.accessible_name ?? '';
		const label = title !== '' ? title : (access !== '' ? access : child.style_class);
		rows.push({label, item});
	}
	return rows;
}

function runProve(main) {
	const qs = main.panel.statusArea.quickSettings;
	const brightness = main.panel._brightness?.quickSettingsItems?.[0];
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
	ensureGridRow(qs.menu);
	logMenus(qs.menu._grid);
	if (brightness?.menu == null || !brightness.visible)
		smokeLog('brightness hidden');
	const rows = visibleMenus(qs.menu._grid);
	qs.menu.open(0);
	later(400, () => {
		if (!qs.menu.isOpen) {
			smokeLog('miss quick-settings-closed');
			global.context.terminate();
			return;
		}
		const scoreAt = (index, anyHigh) => {
			if (index >= rows.length) {
				smokeLog(anyHigh ? 'miss overlap' : 'ok');
				global.context.terminate();
				return;
			}
			const row = rows[index];
			if (row.item.menuEnabled === false)
				row.item.menuEnabled = true;
			row.item.menu.open(0);
			later(800, () => {
				const parent = row.item.menu.actor.get_parent();
				const rel = row.item.apply_relative_transform_to_point(
					parent, new Graphene.Point3D());
				smokeLog(`${row.label} relative=${rel.x},${rel.y} y=${row.item.y}`);
				const high = report(row.label, row.item, row.item.menu);
				row.item.menu.close(0);
				scoreAt(index + 1, anyHigh || high);
			});
		};
		scoreAt(0, false);
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
					const qs = main.panel?.statusArea?.quickSettings;
					const ready = qs != null
						&& qs._volumeOutput?._output?.menu != null
						&& qs._system?._systemItem?.menu?.sourceActor != null;
					if (!ready && GLib.get_monotonic_time() < deadline)
						return GLib.SOURCE_CONTINUE;
					if (!ready) {
						smokeLog('miss no-menu');
						global.context.terminate();
						return GLib.SOURCE_REMOVE;
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
