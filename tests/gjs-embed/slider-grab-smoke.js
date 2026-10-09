/**
 * Press the left slider, then the right one. The second press must
 * change the right slider. A grab that survives the first release
 * delivers that press to the left slider.
 *
 *   GI_META_SMOKE=slider-grab-smoke ./scripts/weston-gsr-prove.sh
 */
import GLib from 'gi://GLib';

import 'resource:///org/gnome/shell/ui/environment.js';
import {Slider} from 'resource:///org/gnome/shell/ui/slider.js';

imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const Clutter = imports.gi.Clutter;
const GObject = imports.gi.GObject;
const Shell = imports.gi.Shell;

let presses = [];

function quit(reason) {
	console.log(`slider-grab-smoke: quit (${reason})`);
	const ctx = global.context;
	if (ctx?.terminate)
		ctx.terminate();
}

const Probe = GObject.registerClass(
class Probe extends Slider {
	vfunc_button_press_event(event) {
		const before = this._dragging;
		const result = super.vfunc_button_press_event(event);
		presses.push(
			`${this.name} press before=${before} after=${this._dragging} grab=${this._grab ? 'set' : 'null'}`);
		console.log(`slider-grab-smoke: ${presses[presses.length - 1]}`);
		return result;
	}

	vfunc_button_release_event(event) {
		const beforeDrag = this._dragging;
		const beforeGrab = this._grab ? 'set' : 'null';
		const result = super.vfunc_button_release_event(event);
		const line =
			`${this.name} release beforeDrag=${beforeDrag} beforeGrab=${beforeGrab} afterDrag=${this._dragging} afterGrab=${this._grab ? 'set' : 'null'}`;
		console.log(`slider-grab-smoke: ${line}`);
		return result;
	}
});

function clickPoint(actor) {
	const [x, y] = actor.get_transformed_position();
	return [x + actor.width / 2 + 38, y + actor.height / 2 + 59];
}

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		try {
			const globalObj = Shell.Global.get();
			const stage = globalObj.get_stage();
			const left = new Probe(0.2);
			left.name = 'left';
			left.set_position(40, 80);
			left.set_size(220, 40);
			stage.add_child(left);
			const right = new Probe(0.2);
			right.name = 'right';
			right.set_position(280, 80);
			right.set_size(220, 40);
			stage.add_child(right);

			GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1500, () => {
				let leftAfter = left.value;
				try {
					const [lx, ly] = clickPoint(left);
					console.log(
						`slider-grab-smoke: left click=${lx},${ly} value=${left.value}`);
					globalObj.pointer_click(lx, ly);
					leftAfter = left.value;
					const [rx, ry] = clickPoint(right);
					console.log(
						`slider-grab-smoke: right click=${rx},${ry} left=${left.value} right=${right.value}`);
					globalObj.pointer_click(rx, ry);
				} catch (e) {
					console.log(`slider-grab-smoke: click threw ${e}`);
					quit('done');
					return GLib.SOURCE_REMOVE;
				}
				GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
					console.log(
						`slider-grab-smoke: after left=${left.value} right=${right.value} leftAfter=${leftAfter}`);
					if (right.value > 0.4 && right.value < 0.7
							&& Math.abs(left.value - leftAfter) < 0.05)
						console.log(
							`slider-grab-smoke: ok left=${left.value} right=${right.value}`);
					else
						console.log(
							`slider-grab-smoke: miss left=${left.value} right=${right.value} presses=${presses.join(' | ')}`);
					quit('done');
					return GLib.SOURCE_REMOVE;
				});
				return GLib.SOURCE_REMOVE;
			});
		} catch (e) {
			console.error('slider-grab-smoke: failed', e);
			quit('smoke failed');
		}
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log('slider-grab-smoke: hook registered');
