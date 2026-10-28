/**
 * Reproduce the stock QuickToggleMenu Y constraint, then exercise only
 * allocation/notification relays on the existing actors and constraint.
 *
 *   GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh
 */
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Graphene from 'gi://Graphene';
import St from 'gi://St';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'menu-expander-overlap/ui/init';

function smokeLog(message) {
	log(`${SMOKE}: ${message}`);
}

function place(actor) {
	const own = actor.get_allocation_box();
	let x = 0;
	let y = 0;
	for (let current = actor; current != null; current = current.get_parent()) {
		const box = current.get_allocation_box();
		x += box.x1;
		y += box.y1;
	}
	return {
		x,
		y,
		w: own.x2 - own.x1,
		h: own.y2 - own.y1,
	};
}

function report(label, source, menu) {
	const sourceBox = place(source);
	const menuBox = place(menu.actor);
	const gap = menuBox.y - (sourceBox.y + sourceBox.h);
	const finite = [
		sourceBox.y,
		sourceBox.h,
		menuBox.y,
		menuBox.h,
	].every(Number.isFinite);
	const high = !finite || gap < -2;
	smokeLog(`${label} source=${sourceBox.x},${sourceBox.y}`
		+ ` ${sourceBox.w}x${sourceBox.h}`
		+ ` menu=${menuBox.x},${menuBox.y} ${menuBox.w}x${menuBox.h}`
		+ ` menuY=${menu.actor.get_allocation_box().y1}`
		+ ` height=${source.height} gap=${gap} high=${high}`);
	return high;
}

function visibleMenus(grid) {
	const rows = [];
	for (const child of grid) {
		const item = child.menu != null ? child : child._delegate;
		if (item?.menu == null || !child.visible)
			continue;
		const title = item.title ?? child.accessible_name ?? child.style_class;
		rows.push({label: title || child.style_class, item});
	}
	return rows;
}

function ensureGridRow(menu) {
	const grid = menu._grid;
	for (const child of grid) {
		if (child.visible)
			return;
	}
	grid.add_child(new St.Widget({width: 40, height: 40}));
}

function run(main) {
	const quickSettings = main.panel.statusArea.quickSettings;
	ensureGridRow(quickSettings.menu);
	const rows = visibleMenus(quickSettings.menu._grid);
	const later = (ms, callback) => {
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
			try {
				callback();
			} catch (error) {
				smokeLog(`miss threw ${formatError(error)}`);
				global.context.terminate();
			}
			return GLib.SOURCE_REMOVE;
		});
	};

	quickSettings.menu.open(0);
	later(400, () => {
		const check = (index, sawFailure, trialHigh) => {
			if (index >= rows.length) {
				smokeLog(sawFailure && !trialHigh
					? 'ok'
					: `miss failure=${sawFailure} trial-high=${trialHigh}`);
				global.context.terminate();
				return;
			}

			const {label, item} = rows[index];
			if (item.menuEnabled === false)
				item.menuEnabled = true;
			item.menu.open(0);
			later(500, () => {
				const high = report(label, item, item.menu);
				const menu = item.menu.actor;
				const parent = menu.get_parent();
				const box = menu.get_allocation_box();
				let relY = NaN;
				if (parent != null) {
					relY = item.apply_relative_transform_to_point(
						parent, new Graphene.Point3D()).y;
				}
				const [minH, natH] = menu.get_preferred_height(-1);
				smokeLog(`${label} detail heightProp=${menu.height}`
					+ ` visible=${menu.visible} mapped=${menu.mapped}`
					+ ` nat=${natH} min=${minH} relY=${relY}`
					+ ` boxY=${box.y1} boxH=${box.y2 - box.y1}`
					+ ` parentH=${parent?.height} children=${item.menu.box.get_n_children()}`);

				/* Trial only: the effective Y offset is the source's
				 * client allocation relative to the overlay plus the
				 * height copied by the stock GBinding. */
				menu.clear_constraints();
				menu.add_constraint(new Clutter.BindConstraint({
					coordinate: Clutter.BindCoordinate.Y,
					source: item,
					offset: relY + item.height,
				}));

				later(800, () => {
					const stillHigh = report(`${label}-trial`, item, item.menu);
					const after = menu.get_allocation_box();
					const empty = !Number.isFinite(after.y1)
						|| (after.y2 - after.y1) < 2;
					if (!empty) {
						item.menu.close(0);
						later(800, () => {
							check(
								index + 1,
								sawFailure || high,
								trialHigh || stillHigh);
						});
						return;
					}
					menu.height = -1;
					menu.queue_relayout();
					later(800, () => {
						const recovered = report(`${label}-height`, item, item.menu);
						smokeLog(`${label}-height prop=${menu.height}`
							+ ` nat=${menu.get_preferred_height(-1)[1]}`);
						item.menu.close(0);
						later(800, () => {
							check(
								index + 1,
								sawFailure || high,
								trialHigh || stillHigh || recovered);
						});
					});
				});
			});
		};
		check(0, false, false);
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
					const quickSettings = main.panel?.statusArea?.quickSettings;
					const ready = quickSettings?._system?._systemItem?.menu != null
						&& quickSettings?._volumeOutput?._output?.menu != null;
					if (!ready && GLib.get_monotonic_time() < deadline)
						return GLib.SOURCE_CONTINUE;
					if (!ready) {
						smokeLog('miss no-menu');
						global.context.terminate();
						return GLib.SOURCE_REMOVE;
					}
					run(main);
					return GLib.SOURCE_REMOVE;
				});
			});
		}).catch(error => {
			smokeLog(`miss start ${formatError(error)}`);
			global.context.terminate_with_error(new GLib.Error(
				Gio.IOErrorEnum,
				Gio.IOErrorEnum.FAILED,
				formatError(error)));
		});
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
