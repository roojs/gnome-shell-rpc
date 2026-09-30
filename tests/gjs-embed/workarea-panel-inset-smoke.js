/**
 * FAIL smoke — Meta workarea must inset after a top-edge builtin strut.
 *
 * Stock layout.js: panelBox addChrome({affectsStruts:true}) → _updateRegions
 * builds Meta.Strut TOP → Workspace.set_builtin_struts. ControlsManagerLayout
 * then places search / thumbs / wallpaper at startY = work.y - mon.y.
 * Live chrome: search @ y=0 (probe entryBin) — same miss as wallpaper too
 * high and the desktop-thumbnail row sitting under the panel.
 *
 *   GI_META_SMOKE=workarea-panel-inset-smoke GSR_WESTON_MODE=prove \
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

const { GLib, Shell, Meta, Mtk } = imports.gi;

const SMOKE_DOMAIN = 'workarea-panel-inset-smoke';
const PANEL_H = 32;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * @param {object} r
 * @returns {string}
 */
function rectS(r) {
	if (!r)
		return 'null';
	return `${r.x},${r.y} ${r.width}x${r.height}`;
}

function main() {
	const globalObj = Shell.Global.get();
	if (globalObj == null)
		throw new Error(SMOKE_DOMAIN + ': Global is null');

	const display = globalObj.get_display();
	const wm = globalObj.workspace_manager;
	const ws = wm.get_workspace_by_index(0);
	if (display == null || ws == null)
		throw new Error(SMOKE_DOMAIN + ': display/workspace0 null');

	const mon = display.get_monitor_geometry(0);
	const before = ws.get_work_area_for_monitor(0);
	smokeLog(`A monitor ${rectS(mon)} work ${rectS(before)}`);

	let strutOk = false;
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
		strutOk = true;
		smokeLog('B set_builtin_struts TOP h=' + PANEL_H);
	} catch (e) {
		smokeLog('FAIL set_builtin_struts-threw ' + e);
	}

	const check = (tag) => {
		const after = ws.get_work_area_for_monitor(0);
		const startY = after.y - mon.y;
		const insetH = mon.height - after.height;
		smokeLog(`${tag} work ${rectS(after)} startY=${startY} insetH=${insetH}`);
		const inset = startY >= PANEL_H - 2 && after.height <= mon.height - PANEL_H + 2;
		if (!inset) {
			smokeLog(`FAIL workarea-not-inset-for-panel startY=${startY} ` +
				`work=${after.width}x${after.height} mon=${mon.width}x${mon.height}`);
			return false;
		}
		return true;
	};

	let inset = strutOk && check('C-immediate');
	if (strutOk && !inset) {
		const loop = new GLib.MainLoop(null, false);
		GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
			inset = check('D-200ms');
			if (inset)
				smokeLog('PASS');
			smokeLog('done');
			loop.quit();
			return GLib.SOURCE_REMOVE;
		});
		loop.run();
		return;
	}

	if (inset)
		smokeLog('PASS');
	smokeLog('done');
}

main();
