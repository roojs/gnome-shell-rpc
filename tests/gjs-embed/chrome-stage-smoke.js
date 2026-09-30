/**
 * Prove St chrome paints on the nested Meta stage (dummy top bar).
 *
 * Full init.js builds Panel before wallpaper; if you cannot see this red
 * strip, the wall is stage paint / parenting — not panel.js logic.
 *
 *   GI_META_SMOKE=chrome-stage-smoke.js \
 *     dbus-run-session ./build/src/mutter-rpc --debug --wayland --nested
 *
 * Look at the nested window for a red bar with "MENU SMOKE". Quits after 12s.
 */
import GLib from 'gi://GLib';

import 'resource:///org/gnome/shell/ui/environment.js';

imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const St = imports.gi.St;
const Clutter = imports.gi.Clutter;
const Shell = imports.gi.Shell;

const HOLD_MS = 12000;
const BAR_H = 48;

function quit(reason) {
	console.log(`chrome-stage-smoke: quit (${reason})`);
	const ctx = global.context;
	if (ctx?.terminate) {
		ctx.terminate();
		return;
	}
	if (ctx?.terminate_with_error) {
		ctx.terminate_with_error(
			new GLib.Error(
				imports.gi.Gio.IOErrorEnum,
				imports.gi.Gio.IOErrorEnum.FAILED,
				reason));
	}
}

function placeBar(stage, bar, width) {
	const [sw, sh] = stage.get_size();
	console.log(`chrome-stage-smoke: stage size=${sw}x${sh}`);
	const w = width > 0 ? width : Math.max(sw, 320);
	bar.set_position(0, 0);
	bar.set_size(w, BAR_H);
	bar.show();
	console.log(
		`chrome-stage-smoke: bar visible=${bar.visible} ` +
		`size=${bar.width}x${bar.height} on_stage=${bar.get_stage() != null}`);
}

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		try {
			const globalObj = Shell.Global.get();
			const stage = globalObj.get_stage();
			if (stage == null) {
				throw new Error('Shell.Global.get_stage() is null');
			}

			const display = globalObj.get_display();
			const [dw, dh] = display.get_size();
			const nMon = display.get_n_monitors();
			let monW = 0;
			let monH = 0;
			let monGeom = '';
			for (let i = 0; i < nMon; i++) {
				const r = display.get_monitor_geometry(i);
				monGeom += ` [${i}]=${r.x},${r.y} ${r.width}x${r.height}`;
				if (r.width > monW) {
					monW = r.width;
					monH = r.height;
				}
			}
			console.log(
				`chrome-stage-smoke: display.get_size=${dw}x${dh} ` +
				`screen=${globalObj.screen_width}x${globalObj.screen_height} ` +
				`n_monitors=${nMon}${monGeom}`);

			const bar = new St.BoxLayout({
				name: 'chrome-stage-smoke-bar',
				reactive: true,
				x_expand: true,
				style_class: '',
			});
			bar.set_style(
				'background-color: #c41e3a; color: #ffffff; ' +
				'font-size: 22px; padding: 8px;');

			const label = new St.Label({
				text: 'MENU SMOKE',
				y_align: Clutter.ActorAlign.CENTER,
			});
			bar.add_child(label);

			stage.add_child(bar);
			/* Prefer monitor geometry — Display/stage get_size are 0x0 on wire. */
			const barW = monW > 0 ? monW : dw;
			placeBar(stage, bar, barW);

			stage.connect('notify::width', () => placeBar(stage, bar, barW));
			stage.connect('notify::height', () => placeBar(stage, bar, barW));

			console.log(
				`chrome-stage-smoke: red bar on stage — hold ${HOLD_MS}ms ` +
				`(look for MENU SMOKE; monitor ${monW}x${monH})`);
			GLib.timeout_add(GLib.PRIORITY_DEFAULT, HOLD_MS, () => {
				placeBar(stage, bar, barW);
				const [sw2, sh2] = stage.get_size();
				const [dw2, dh2] = display.get_size();
				console.log(
					`chrome-stage-smoke: end stage=${sw2}x${sh2} ` +
					`display=${dw2}x${dh2}`);
				quit('hold done');
				return GLib.SOURCE_REMOVE;
			});
		} catch (e) {
			console.error('chrome-stage-smoke: failed', e);
			quit('smoke failed');
		}
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});

console.log('chrome-stage-smoke: hook registered');
