/**
 * Reproduce the missing current event seen by GNOME Shell DND.
 *
 * Stock dnd.js handles ClickAction::long-press CANCEL by calling
 * Clutter.get_current_event(), then reads the event sequence, time, and device.
 *
 * Pass: `current-event-long-press-smoke: ok`
 * Fail: `current-event-long-press-smoke: miss current-event-null`
 *
 *   GI_META_SMOKE=current-event-long-press-smoke \
 *   GSR_WESTON_PIXMAN=1 ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Clutter = '16';
imports.gi.versions.GLib = '2.0';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';

const {Clutter, GLib, Shell, St} = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';

const SMOKE = 'current-event-long-press-smoke';

function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function waitMs(ms) {
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

async function run() {
	const main = await import('resource:///org/gnome/shell/ui/main.js');
	const dnd = await import('resource:///org/gnome/shell/ui/dnd.js');
	await main.start();

	const globalObj = Shell.Global.get();
	const stage = globalObj.stage;
	const actor = new St.Widget({
		reactive: true,
	});
	actor.set_position(100, 100);
	actor.set_size(200, 120);
	actor.set_style('background-color: #ff0000;');
	stage.add_child(actor);

	const action = new Clutter.ClickAction();
	const draggable = dnd.makeDraggable(actor, {restoreOnSuccess: true});
	draggable.addClickAction(action);
	let sawCancel = false;
	let currentEvent = null;
	action.connect('long-press', (_action, _actor, state) => {
		if (state !== Clutter.LongPressState.CANCEL)
			return true;
		sawCancel = true;
		currentEvent = Clutter.get_current_event();
		smokeLog('cancel current-event=' + (currentEvent == null ? 'null' : 'set'));
		return true;
	});
	actor.add_action(action);

	globalObj.pointer_click(200, 160);
	waitMs(300);

	if (!sawCancel)
		smokeLog('miss no-long-press-cancel');
	else if (currentEvent == null)
		smokeLog('miss current-event-null');
	else
		smokeLog('ok');

	actor.destroy();
	globalObj.context.terminate();
}

imports._promiseNative.setMainLoopHook(() => {
	run().catch(e => {
		smokeLog('miss exception ' + e);
		Shell.Global.get().context.terminate();
	});
	Shell.Global.get().context.run_main_loop();
});
