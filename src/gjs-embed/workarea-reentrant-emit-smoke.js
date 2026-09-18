/**
 * FAIL smoke — `Workspace.set_builtin_struts` must NOT re-emit
 * `Display::workareas-changed` **inline / on-stack** (re-entrant).
 *
 * Regression corridor (`e1a7c46..HEAD`, see
 * docs/bugs/2026-09-18-hang-after-settle-race.md P2):
 *   - `overrides/Workspace.override.set_builtin_struts` RPCs the server and
 *     then `emit_by_name(display, "workareas-changed")` **synchronously**.
 *   - `overrides/Meta.override.get_display` subscribes the client Display
 *     proxy to `workareas-changed`, and `gi-stub/Runtime.default` re-emits it
 *     again from the server Notification.
 *
 * Stock mutter emits `workareas-changed` **later** (off the caller's stack),
 * so `_updateRegions`' handler never re-enters the strut apply synchronously.
 * Our inline emit runs handlers **on the call stack** — and when that call
 * stack is a `Live.Invoke` handler (the LM preferred-height relay, blocked
 * server mid-`hook.emit`), the handler's sync `get_work_area_for_monitor` /
 * `set_builtin_struts` round-trip deadlocks (P2 backtrace).
 *
 *   GI_META_SMOKE=workarea-reentrant-emit-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * PASS → set_builtin_struts does not emit workareas-changed on-stack (fixed:
 *        the emit is deferred / left to the server Notification only).
 * FAIL → inline on-stack re-emit present → the re-entrant corridor that
 *        deadlocks inside the LM relay. Fix (consumer): drop the manual
 *        emit in set_builtin_struts and/or defer the client workareas-changed
 *        emit to an idle, out of the relay/emit stack.
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

const SMOKE_DOMAIN = 'workarea-reentrant-emit-smoke';
const PANEL_H = 32;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
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
	smokeLog(`monitor ${mon.x},${mon.y} ${mon.width}x${mon.height}`);

	/*
	 * Track whether workareas-changed fires WHILE set_builtin_struts is still
	 * on the call stack (inCall === true). That is the on-stack re-entrancy
	 * that stock mutter never does and that deadlocks inside the LM relay.
	 */
	let inCall = false;
	let syncHits = 0;
	let asyncHits = 0;
	const waId = display.connect('workareas-changed', () => {
		if (inCall)
			syncHits++;
		else
			asyncHits++;
		smokeLog(`workareas-changed inCall=${inCall} sync=${syncHits} async=${asyncHits}`);
	});

	const strut = new Meta.Strut({
		rect: new Mtk.Rectangle({
			x: mon.x,
			y: mon.y,
			width: mon.width,
			height: PANEL_H,
		}),
		side: Meta.Side.TOP,
	});

	try {
		inCall = true;
		ws.set_builtin_struts([strut]);
		inCall = false;
		smokeLog(`set_builtin_struts returned syncHits=${syncHits}`);
	} catch (e) {
		inCall = false;
		smokeLog('FAIL set_builtin_struts-threw ' + e);
	}

	/* Let the server Notification (the legitimate, off-stack path) arrive. */
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 400, () => {
		smokeLog(`final syncHits=${syncHits} asyncHits=${asyncHits}`);
		if (syncHits > 0) {
			smokeLog(
				`FAIL reentrant-onstack-emit syncHits=${syncHits} ` +
				'(set_builtin_struts emits workareas-changed inline; ' +
				'stock defers it — on-stack emit deadlocks the LM relay)');
		} else {
			smokeLog('PASS');
		}
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
