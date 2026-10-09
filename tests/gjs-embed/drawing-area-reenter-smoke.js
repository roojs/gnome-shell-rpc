/**
 * Call queue_repaint from inside vfunc_repaint. Stock
 * st_drawing_area_queue_repaint emits repaint before it returns, so
 * this is a second emission while the first is still on the stack.
 * The 14:30 hold died on that shape: get_context after in_repaint
 * was cleared.
 *
 *   GI_META_SMOKE=drawing-area-reenter-smoke ./scripts/weston-gsr-prove.sh
 */
import GLib from 'gi://GLib';

import 'resource:///org/gnome/shell/ui/environment.js';

imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const St = imports.gi.St;
const GObject = imports.gi.GObject;
const Shell = imports.gi.Shell;

let depth = 0;
let maxDepth = 0;
let entered = 0;
let drewW = 0;
let drewH = 0;
let finished = false;

function quit(reason) {
	console.log(`drawing-area-reenter-smoke: quit (${reason})`);
	const ctx = global.context;
	if (ctx?.terminate)
		ctx.terminate();
}

function finish() {
	if (finished)
		return;
	finished = true;
	if (maxDepth === 1 && entered >= 2 && drewW >= 32 && drewH >= 32) {
		console.log(`drawing-area-reenter-smoke: ok depth=${maxDepth} entered=${entered} surface=${drewW}x${drewH}`);
		quit('ok');
		return;
	}
	console.log(`drawing-area-reenter-smoke: miss depth=${maxDepth} entered=${entered} surface=${drewW}x${drewH}`);
	quit('miss');
}

const ProbeArea = GObject.registerClass(
class ProbeArea extends St.DrawingArea {
	_init(params) {
		super._init(params);
		this._queued = false;
	}

	vfunc_get_preferred_width(_forHeight) {
		return [480, 480];
	}

	vfunc_get_preferred_height(_forWidth) {
		return [64, 64];
	}

	vfunc_repaint() {
		entered += 1;
		depth += 1;
		if (depth > maxDepth)
			maxDepth = depth;
		const here = depth;
		console.log(`drawing-area-reenter-smoke: enter depth=${here}`);
		if (!this._queued) {
			this._queued = true;
			try {
				this.queue_repaint();
				console.log(`drawing-area-reenter-smoke: queue_repaint returned depth=${depth}`);
			} catch (e) {
				console.log(`drawing-area-reenter-smoke: queue_repaint threw ${e}`);
			}
		}
		try {
			const cr = this.get_context();
			let w = 1;
			let h = 1;
			try {
				[w, h] = this.get_surface_size();
			} catch (e) {
				console.log(`drawing-area-reenter-smoke: get_surface_size threw ${e}`);
			}
			cr.setSourceRGBA(0, 1, 0, 1);
			cr.rectangle(0, 0, Math.max(w, 1), Math.max(h, 1));
			cr.fill();
			cr.$dispose();
			if (w >= 32 && h >= 32) {
				drewW = w;
				drewH = h;
			}
			console.log(`drawing-area-reenter-smoke: drew depth=${here} surface=${w}x${h}`);
		} catch (e) {
			console.log(`drawing-area-reenter-smoke: draw threw ${e}`);
		}
		depth -= 1;
	}
});

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		try {
			const stage = Shell.Global.get().get_stage();
			const area = new ProbeArea({
				name: 'drawing-area-reenter-smoke',
				reactive: true,
			});
			stage.add_child(area);
			area.set_position(40, 40);
			area.set_size(480, 64);
			area.show();
			console.log('drawing-area-reenter-smoke: on stage');
			GLib.timeout_add(GLib.PRIORITY_DEFAULT, 800, () => {
				area.queue_repaint();
				console.log('drawing-area-reenter-smoke: queued');
				return GLib.SOURCE_REMOVE;
			});
			GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2500, () => {
				finish();
				return GLib.SOURCE_REMOVE;
			});
		} catch (e) {
			console.error('drawing-area-reenter-smoke: failed', e);
			quit('smoke failed');
		}
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log('drawing-area-reenter-smoke: hook registered');
