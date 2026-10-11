/**
 * The volume arrow and the power button must sit above the list they
 * open, not on it. QuickToggleMenu binds its Y to the source and sets
 * the constraint offset from the source height.
 *
 *   GI_META_SMOKE=menu-expander-overlap ./scripts/weston-gsr-prove.sh
 */
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import 'resource:///org/gnome/shell/ui/environment.js';
import {formatError} from 'resource:///org/gnome/shell/misc/errorUtils.js';

const SMOKE = 'menu-expander-overlap';

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
	/* The list belongs at or below the control. A negative gap means
	 * the list starts on the control. */
	const high = finite && gap < -2;
	smokeLog(`${label} source=${s.x},${s.y} ${s.w}x${s.h}`
		+ ` menu=${m.x},${m.y} ${m.w}x${m.h}`
		+ ` nat=${nat} gap=${gap} open=${menu.isOpen}`
		+ ` finite=${finite} high=${high}`);
	smokeLog(`${label} source-chain ${s.chain}`);
	smokeLog(`${label} menu-chain ${m.chain}`);
	return !finite || high;
}

/**
 * @param {object} main
 */
function runProve(main) {
	const qs = main.panel.statusArea.quickSettings;
	const output = qs._volumeOutput._output;
	const shutdown = qs._system._systemItem.menu.sourceActor;
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
	qs.menu.open(0);
	later(400, () => {
		if (!qs.menu.isOpen) {
			smokeLog('miss quick-settings-closed');
			global.context.terminate();
			return;
		}
		output.menuEnabled = true;
		output.menu.open(0);
		later(300, () => {
			const volumeHigh = report('volume', output, output.menu);
			output.menu.close(0);
			shutdown.menu.open(0);
			later(300, () => {
				const powerHigh = report('power', shutdown, shutdown.menu);
				if (volumeHigh || powerHigh) {
					smokeLog('miss overlap');
					global.context.terminate();
					return;
				}
				smokeLog('ok');
				global.context.terminate();
			});
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
