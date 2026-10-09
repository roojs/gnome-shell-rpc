/**
 * Click a DrawingArea probe, then a real Slider. A press that reaches
 * the slider must change its value the way a volume click does.
 *
 *   GI_META_SMOKE=slider-click-smoke ./scripts/weston-gsr-prove.sh
 */
import GLib from 'gi://GLib';

import 'resource:///org/gnome/shell/ui/environment.js';
import {Slider} from 'resource:///org/gnome/shell/ui/slider.js';

imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const St = imports.gi.St;
const Clutter = imports.gi.Clutter;
const GObject = imports.gi.GObject;
const Shell = imports.gi.Shell;

let probePresses = 0;
let probeSeq = 'unset';
let sliderHandler = 'unset';
let sliderValue = -1;

function quit(reason) {
	console.log(`slider-click-smoke: quit (${reason})`);
	const ctx = global.context;
	if (ctx?.terminate)
		ctx.terminate();
}

const ProbeArea = GObject.registerClass(
class ProbeArea extends St.DrawingArea {
	vfunc_button_press_event(event) {
		probePresses += 1;
		try {
			const seq = event.get_event_sequence();
			probeSeq = seq == null ? 'null' : 'object';
		} catch (e) {
			probeSeq = `threw ${e}`;
		}
		console.log(`slider-click-smoke: probe press seq=${probeSeq}`);
		return Clutter.EVENT_STOP;
	}
});

function centerOf(actor) {
	const [x, y] = actor.get_transformed_position();
	// Nested X11 virtual pointer uses root coordinates. The 08:50 run
	// asked for 140,60 and the window event landed at 102,1.
	return [x + actor.width / 2 + 38, y + actor.height / 2 + 59];
}

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		try {
			const globalObj = Shell.Global.get();
			const stage = globalObj.get_stage();
			const probe = new ProbeArea({
				name: 'slider-click-probe',
				reactive: true,
				width: 200,
				height: 40,
			});
			probe.set_position(40, 40);
			stage.add_child(probe);

			const slider = new Slider(0.2);
			slider.set_position(40, 120);
			slider.set_size(400, 40);
			stage.add_child(slider);
			slider.connect('button-press-event', (_actor, event) => {
				try {
					const seq = event.get_event_sequence();
					sliderHandler = seq == null ? 'seq-null' : 'seq-object';
					const grab = globalObj.get_stage().grab(slider);
					sliderHandler += grab ? ' grab-ok' : ' grab-null';
				} catch (e) {
					sliderHandler = `threw ${e}`;
				}
				console.log(`slider-click-smoke: slider handler ${sliderHandler}`);
				return Clutter.EVENT_PROPAGATE;
			});

			GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1500, () => {
				try {
					const [px, py] = centerOf(probe);
					console.log(
						`slider-click-smoke: probe size=${probe.width}x${probe.height} reactive=${probe.reactive} click=${px},${py}`);
					globalObj.pointer_click(px, py);
					const [sx, sy] = centerOf(slider);
					console.log(
						`slider-click-smoke: slider size=${slider.width}x${slider.height} reactive=${slider.reactive} value=${slider.value} click=${sx},${sy}`);
					const allocW = slider.allocation.get_width();
					globalObj.pointer_click(sx, sy);
					const clicked = slider.value;
					globalObj.pointer_scroll(sx, sy, Clutter.ScrollDirection.UP);
					sliderValue = slider.value;
					console.log(
						`slider-click-smoke: after probePresses=${probePresses} allocW=${allocW} clicked=${clicked} sliderValue=${sliderValue} handler=${sliderHandler}`);
				} catch (e) {
					console.log(`slider-click-smoke: click threw ${e}`);
				}
				GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
					const allocW = slider.allocation.get_width();
					// Center click is about 0.5. One wheel-up notch adds 0.02.
					if (probePresses > 0 && allocW >= 300
							&& slider.value > 0.51 && slider.value < 0.54)
						console.log(`slider-click-smoke: ok value=${slider.value} allocW=${allocW}`);
					else
						console.log(
							`slider-click-smoke: miss presses=${probePresses} value=${slider.value} allocW=${allocW} handler=${sliderHandler} seq=${probeSeq}`);
					quit('done');
					return GLib.SOURCE_REMOVE;
				});
				return GLib.SOURCE_REMOVE;
			});
		} catch (e) {
			console.error('slider-click-smoke: failed', e);
			quit('smoke failed');
		}
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log('slider-click-smoke: hook registered');
