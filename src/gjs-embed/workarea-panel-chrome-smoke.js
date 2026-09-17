/**
 * FAIL smoke — stock layout.js strut apply / workarea refresh, not Meta
 * set_builtin_struts (that gate PASSed: startY=32).
 *
 * Stock (_updateRegions / ControlsManagerLayout):
 *   A  compositor.get_laters().add(BEFORE_REDRAW) must run
 *   B  Display.get_monitor_index_for_rect(panel-sized top rect) >= 0
 *      else findMonitorForActor is null and no strut is built
 *   C  Display.workareas-changed after set_builtin_struts — else
 *      _workAreaBox stays at construct-time startY=0
 *
 *   GI_META_SMOKE=workarea-panel-chrome-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Weston only. Do not run mutter-rpc on the host DISPLAY.
 * Prove-only — does not patch stubs/Helpers.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Mtk = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GLib, Shell, Meta, Mtk, St } = imports.gi;

const SMOKE_DOMAIN = 'workarea-panel-chrome-smoke';
const PANEL_H = 32;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * @param {boolean} ok
 * @param {string} label
 * @param {string} [detail]
 */
function assert(ok, label, detail) {
	if (ok) {
		smokeLog('PASS ' + label + (detail ? ' ' + detail : ''));
		return;
	}
	smokeLog('FAIL ' + label + (detail ? ' ' + detail : ''));
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	const display = globalObj.get_display();
	if (stage == null || display == null)
		throw new Error(SMOKE_DOMAIN + ': stage/display null');

	const mon = display.get_monitor_geometry(0);
	smokeLog(`monitor ${mon.x},${mon.y} ${mon.width}x${mon.height}`);

	/* A — stock _queueUpdateRegions later must fire. */
	let laterHits = 0;
	try {
		const compositor = globalObj.compositor ?? display.get_compositor?.();
		const laters = compositor.get_laters();
		laters.add(Meta.LaterType.BEFORE_REDRAW, () => {
			laterHits++;
			smokeLog('A later BEFORE_REDRAW hit=' + laterHits);
			return GLib.SOURCE_REMOVE;
		});
	} catch (e) {
		smokeLog('FAIL A get_laters-threw ' + e);
	}

	/* B — findIndexForActor: monitor index for a top-edge panel rect. */
	const bar = new St.Widget({
		name: 'workarea-panel-chrome-bar',
	});
	bar.set_position(mon.x, mon.y);
	bar.set_size(mon.width, PANEL_H);
	stage.add_child(bar);
	bar.show();
	const [bx, by] = bar.get_transformed_position();
	const [bw, bh] = bar.get_transformed_size();
	smokeLog(`B bar transformed ${bx.toFixed(0)},${by.toFixed(0)} ${bw.toFixed(0)}x${bh.toFixed(0)}`);
	let monIdx = -2;
	try {
		const rect = new Mtk.Rectangle({
			x: Math.round(bx),
			y: Math.round(by),
			width: Math.round(bw),
			height: Math.round(bh),
		});
		monIdx = display.get_monitor_index_for_rect(rect);
		smokeLog('B get_monitor_index_for_rect=' + monIdx);
	} catch (e) {
		smokeLog('FAIL B get_monitor_index_for_rect-threw ' + e);
	}

	/* C — workareas-changed after the same strut chrome uses. */
	const ws = globalObj.workspace_manager.get_workspace_by_index(0);
	let workareasHits = 0;
	const waId = display.connect('workareas-changed', () => {
		workareasHits++;
		smokeLog('C workareas-changed hit=' + workareasHits);
	});
	try {
		const strutRect = new Mtk.Rectangle({
			x: mon.x,
			y: mon.y,
			width: mon.width,
			height: PANEL_H,
		});
		const strut = new Meta.Strut({
			rect: strutRect,
			side: Meta.Side.TOP,
		});
		ws.set_builtin_struts([strut]);
		smokeLog('C set_builtin_struts');
	} catch (e) {
		smokeLog('FAIL C set_builtin_struts-threw ' + e);
	}

	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 400, () => {
		assert(laterHits >= 1, 'A', `laterHits=${laterHits} (stock _queueUpdateRegions)`);
		assert(monIdx >= 0, 'B', `monitorIndex=${monIdx} (findMonitorForActor)`);
		assert(workareasHits >= 1, 'C',
			`workareasHits=${workareasHits} (ControlsManagerLayout._updateWorkAreaBox)`);
		if (laterHits >= 1 && monIdx >= 0 && workareasHits >= 1)
			smokeLog('PASS');
		try {
			display.disconnect(waId);
		} catch (e) {}
		smokeLog('done');
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
