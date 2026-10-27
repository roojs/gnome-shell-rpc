/**
 * The volume arrow and the power button must sit above the list they
 * open, not on it. QuickToggleMenu binds its Y to the source and sets
 * the constraint offset from the source height.
 *
 *   GI_META_SMOKE=menu-expander-overlap/ui/init ./scripts/weston-gsr-prove.sh
 */
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Graphene from 'gi://Graphene';
import Shell from 'gi://Shell';
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
/**
 * Stage pixels, including translation. The allocation chain misses that.
 *
 * @param {object} actor
 */
function transformed(actor) {
	const [x, y] = actor.get_transformed_position();
	const [w, h] = actor.get_transformed_size();
	return {x, y, w, h};
}

/**
 * @param {string} label
 * @param {object} source
 * @param {object} menu
 */
function report(label, source, menu) {
	const s = place(source);
	const m = place(menu.actor);
	const contentActor = menu.box ?? menu.actor;
	const button = transformed(source);
	const content = transformed(contentActor);
	let item = 'none';
	const first = contentActor.get_first_child?.() ?? null;
	if (first != null) {
		const kid = transformed(first);
		item = `${kid.y}+${kid.h}`;
	}
	const [, nat] = menu.actor.get_preferred_height(-1);
	const gap = m.y - (s.y + s.h);
	const paintedGap = content.y - (button.y + button.h);
	const finite = [s.y, s.h, m.x, m.y, m.w, m.h].every(Number.isFinite);
	const own = menu.actor.get_allocation_box();
	const sourceHeight = source.height;
	/* The list belongs at or below the control. A negative gap means
	 * the list starts on the control. The container allocation can be
	 * height 0 while menu.box is the painted list. */
	const gapHigh = finite && gap < -2;
	const paintedHigh = [button.y, button.h, content.y].every(Number.isFinite)
		&& paintedGap < -2;
	const unopened = Number.isFinite(nat) && nat > 20
		&& Number.isFinite(content.h) && content.h < 2;
	const unpushed = !finite
		&& Number.isFinite(sourceHeight) && sourceHeight > 2
		&& Number.isFinite(own.y1) && own.y1 + 2 < sourceHeight;
	const high = gapHigh || paintedHigh || unopened || unpushed;
	smokeLog(`${label} source=${s.x},${s.y} ${s.w}x${s.h}`
		+ ` menu=${m.x},${m.y} ${m.w}x${m.h}`
		+ ` nat=${nat} gap=${gap} height=${sourceHeight} menuY=${own.y1}`
		+ ` open=${menu.isOpen} finite=${finite} high=${high} unopened=${unopened}`);
	smokeLog(`${label} painted button=${button.y}+${button.h}`
		+ ` content=${content.y}+${content.h} gap=${paintedGap}`
		+ ` heightProp=${menu.actor.height} item=${item}`);
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

/**
 * @param {object} actor
 * @returns {string}
 */
function actorBits(actor) {
	if (actor == null)
		return 'null';
	const box = transformed(actor);
	const style = actor.style_class ?? '';
	const access = actor.accessible_name ?? '';
	const icon = actor.icon_name ?? '';
	return `${style} access=${access} icon=${icon}`
		+ ` ${Math.round(box.w)}x${Math.round(box.h)}`
		+ ` opacity=${actor.opacity} visible=${actor.visible}`;
}

/**
 * @param {object} actor
 * @returns {string}
 */
function themeAlpha(actor) {
	if (actor == null)
		return 'null';
	try {
		const node = actor.get_theme_node?.();
		if (node == null)
			return 'no-theme';
		const color = node.get_background_color();
		return `a=${color.alpha} rgb=${color.red},${color.green},${color.blue}`;
	} catch (e) {
		return 'theme-err ' + e;
	}
}

/**
 * @param {object} grid
 * @returns {string}
 */
function rowLine(grid) {
	const parts = [];
	for (const child of grid) {
		const p = transformed(child);
		const flag = child.visible ? '' : ' hidden';
		parts.push(`${child.style_class ?? 'row'}@${Math.round(p.y)}+${Math.round(p.h)}${flag}`);
	}
	return parts.join(' ');
}

/**
 * @param {object} systemItem
 * @returns {object|null}
 */
function findShutdown(systemItem) {
	const box = systemItem?.child;
	if (box == null)
		return null;
	for (const child of box) {
		if ((child.accessible_name ?? '') === 'Power Off Menu')
			return child;
	}
	return null;
}

/**
 * @param {object} qs
 */
function logChrome(qs) {
	const box = qs._system?._systemItem?.child;
	if (box != null) {
		for (const child of box) {
			const glyph = child._icon ?? child.child ?? null;
			smokeLog('chrome ' + actorBits(child) + ' glyph=' + actorBits(glyph));
		}
	}
	const slider = qs._volumeOutput?._output;
	if (slider != null) {
		smokeLog('volume ' + actorBits(slider._iconButton)
			+ ' glyph=' + actorBits(slider._icon));
	}
}

/**
 * @param {string} path
 */
function shoot(path) {
	try {
		const stream = Gio.File.new_for_path(path).replace(
			null, false, Gio.FileCreateFlags.NONE, null);
		const shot = new Shell.Screenshot();
		shot.screenshot(false, stream).then(() => {
			stream.close(null);
			smokeLog('shot ' + path);
		}).catch(e => {
			smokeLog('shot miss ' + e);
		});
	} catch (e) {
		smokeLog('shot miss ' + formatError(e));
	}
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
	qs.menu.open();
	later(400, () => {
		if (!qs.menu.isOpen) {
			smokeLog('miss quick-settings-closed');
			global.context.terminate();
			return;
		}
		const popup = qs.menu;
		const pointer = transformed(popup._boxPointer);
		const host = transformed(popup.actor);
		smokeLog(`popup actor=${host.w}x${host.h} boxPointer=${pointer.w}x${pointer.h}`
			+ ` bg=${themeAlpha(popup._boxPointer)} opacity=${popup.actor.opacity}`);
		logChrome(qs);
		const shutdown = findShutdown(qs._system?._systemItem);
		smokeLog('before rows ' + rowLine(popup._grid));
		const cache = GLib.get_home_dir() + '/.cache/gnome-shell-rpc/';
		shoot(cache + 'menu-expander-panel.png');
		if (shutdown != null) {
			const b = transformed(shutdown);
			const px = b.x + b.w / 2;
			const py = b.y + b.h / 2;
			const hit = global.stage.get_actor_at_pos(
				Clutter.PickMode.REACTIVE, px, py);
			smokeLog('power-pick ' + actorBits(hit)
				+ ` at ${Math.round(px)},${Math.round(py)}`);
			shutdown.emit('clicked', shutdown);
		} else {
			smokeLog('miss no-power-button');
		}
		const scoreDash = (anyHigh) => {
			const dash = main.overview?.dash;
			const showApps = dash?.showAppsButton;
			if (dash == null || showApps == null) {
				smokeLog('miss no-dash');
				global.context.terminate();
				return;
			}
			main.overview.showApps();
			const samples = [];
			const sample = (index) => {
				const icon = transformed(showApps);
				const host = transformed(dash);
				samples.push(icon.y);
				smokeLog(`dash sample=${index} translation=${dash.translation_y}`
					+ ` showApps=${icon.y}+${icon.h} dash=${host.y}+${host.h}`);
				if (index < 4) {
					later(200, () => sample(index + 1));
					return;
				}
				let jumped = false;
				for (let i = 1; i < samples.length; i++) {
					if (samples[i - 1] - samples[i] > 160)
						jumped = true;
				}
				if (jumped)
					smokeLog('miss dash-jump ' + samples.join(','));
				else if (anyHigh)
					smokeLog('miss overlap');
				else
					smokeLog('ok');
				global.context.terminate();
			};
			later(200, () => sample(0));
		};
		const scoreAt = (index, anyHigh) => {
			if (index >= rows.length) {
				scoreDash(anyHigh);
				return;
			}
			const row = rows[index];
			if (row.item.menuEnabled === false)
				row.item.menuEnabled = true;
			row.item.menu.open();
			later(800, () => {
				const high = report(row.label, row.item, row.item.menu);
				row.item.menu.close();
				scoreAt(index + 1, anyHigh || high);
			});
		};
		later(1600, () => {
			const menu = shutdown?.menu ?? null;
			const hostNow = transformed(popup.actor);
			const [, overlayNat] = popup._overlay.get_preferred_height(-1);
			smokeLog('after-click open=' + (menu?.isOpen ?? false)
				+ ' actor=' + themeAlpha(menu?.actor)
				+ ' box=' + themeAlpha(menu?.box)
				+ ` boxOpacity=${menu?.box?.opacity ?? 'null'}`
				+ ` actorOpacity=${menu?.actor?.opacity ?? 'null'}`
				+ ` popup=${Math.round(hostNow.w)}x${Math.round(hostNow.h)}`
				+ ` overlayNat=${overlayNat}`);
			smokeLog('after rows ' + rowLine(popup._grid));
			shoot(cache + 'menu-expander-power.png');
			scoreAt(0, false);
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
