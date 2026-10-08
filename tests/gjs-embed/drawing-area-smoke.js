/**
 * Put one St.DrawingArea on the stage. The client repaint draws green
 * into the local cairo surface. A compositor-side probe (not this file)
 * paints the live context during the stock repaint emission.
 *
 *   GI_META_SMOKE=drawing-area-smoke ./scripts/weston-gsr-prove.sh
 */
import GLib from 'gi://GLib';

import 'resource:///org/gnome/shell/ui/environment.js';

imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const St = imports.gi.St;
const Clutter = imports.gi.Clutter;
const GObject = imports.gi.GObject;
const Shell = imports.gi.Shell;

let repaintW = -1;
let repaintH = -1;

function quit(reason) {
	console.log(`drawing-area-smoke: quit (${reason})`);
	const ctx = global.context;
	if (ctx?.terminate)
		ctx.terminate();
}

function finish() {
	if (repaintW >= 32 && repaintH >= 32) {
		console.log(`drawing-area-smoke: ok surface=${repaintW}x${repaintH}`);
		quit('ok');
		return;
	}
	if (repaintW < 0) {
		console.log('drawing-area-smoke: miss no-repaint');
		quit('no-repaint');
		return;
	}
	console.log(`drawing-area-smoke: miss surface=${repaintW}x${repaintH}`);
	quit('small-surface');
}

const ProbeArea = GObject.registerClass(
class ProbeArea extends St.DrawingArea {
	vfunc_get_preferred_width(_forHeight) {
		return [480, 480];
	}

	vfunc_get_preferred_height(_forWidth) {
		return [64, 64];
	}

	vfunc_repaint() {
		const cr = this.get_context();
		let w = 0;
		let h = 0;
		try {
			[w, h] = this.get_surface_size();
		} catch (e) {
			console.log(`drawing-area-smoke: get_surface_size threw ${e}`);
		}
		repaintW = w;
		repaintH = h;
		console.log(`drawing-area-smoke: client repaint surface=${w}x${h}`);
		cr.setSourceRGBA(0, 1, 0, 1);
		cr.rectangle(0, 0, Math.max(w, 1), Math.max(h, 1));
		cr.fill();
		cr.$dispose();
	}
});

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		try {
			const stage = Shell.Global.get().get_stage();
			const box = new St.BoxLayout();
			const area = new ProbeArea({
				name: 'drawing-area-smoke',
				reactive: true,
				y_expand: false,
				x_expand: true,
			});
			box.add_child(new St.Label({text: 'x'}));
			box.add_child(area);
			stage.add_child(box);
			box.set_position(40, 40);
			box.set_size(480, 80);
			box.show();
			console.log(
				`drawing-area-smoke: on stage size=${area.width}x${area.height}`);
			GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1500, () => {
				area.queue_repaint();
				console.log('drawing-area-smoke: queue_repaint');
				return GLib.SOURCE_REMOVE;
			});
			GLib.timeout_add(GLib.PRIORITY_DEFAULT, 3000, () => {
				finish();
				return GLib.SOURCE_REMOVE;
			});
		} catch (e) {
			console.error('drawing-area-smoke: failed', e);
			quit('smoke failed');
		}
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log('drawing-area-smoke: hook registered');
