/**
 * Plain St.Widget captured-event, the quick-settings menu actor.
 *
 * QuickSettingsMenu.actor is `new St.Widget`, not a GJS subclass.
 * PopupMenuManager closes on captured-event. A subclass grabber
 * already receives that signal (captured-event-smoke). This one
 * uses the plain widget, then repeats after a subclass construct.
 *
 *   GI_META_SMOKE=plain-captured-event ./scripts/weston-gsr-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE = 'plain-captured-event';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

/**
 * @param {number} ms
 */
function waitMs(ms) {
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

/**
 * @param {object} stage
 * @param {object} globalObj
 * @param {object} actor
 * @returns {number}
 */
function pressCount(stage, globalObj, actor) {
	let presses = 0;
	let any = 0;
	actor.connect('captured-event', (_a, event) => {
		any++;
		if (event.type() === Clutter.EventType.BUTTON_PRESS
				|| event.type() === Clutter.EventType.TOUCH_BEGIN) {
			presses++;
		}
		return Clutter.EVENT_PROPAGATE;
	});
	stage.add_child(actor);
	actor.show();
	const grab = stage.grab(actor);
	globalObj.pointer_click(260, 60);
	waitMs(200);
	if (grab != null && grab.dismiss)
		grab.dismiss();
	actor.destroy();
	smokeLog('any=' + any + ' presses=' + presses);
	return presses;
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null)
		throw new Error(SMOKE + ': stage is null');

	const plain = new St.Widget({
		name: 'plain-captured',
		reactive: true,
		x: 40,
		y: 40,
		width: 80,
		height: 40,
	});
	const plainPresses = pressCount(stage, globalObj, plain);
	smokeLog('plain saw=' + plainPresses);

	const Sub = GObject.registerClass(
		class Sub extends St.Widget {});
	const sub = new Sub({
		name: 'subclass-captured',
		reactive: true,
		width: 10,
		height: 10,
	});
	stage.add_child(sub);

	const after = new St.Widget({
		name: 'plain-after-subclass',
		reactive: true,
		x: 40,
		y: 40,
		width: 80,
		height: 40,
	});
	const afterPresses = pressCount(stage, globalObj, after);
	smokeLog('after-subclass saw=' + afterPresses);
	sub.destroy();

	if (plainPresses < 1 || afterPresses < 1) {
		smokeLog('miss plain=' + plainPresses + ' after=' + afterPresses);
		return;
	}
	smokeLog('ok');
}

main();
