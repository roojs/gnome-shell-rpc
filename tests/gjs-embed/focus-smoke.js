/**
 * 0.8 Phase B4 — Global.focus_manager + click moves stage key_focus.
 *
 *   GI_META_SMOKE=focus-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Uses St.Widget subclass + Helper-Actor.fire_button_press (B3 path).
 * St.Button peers are stock StButton — not Helper.Actor — so fire_button_press
 * cannot cast them.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'focus-smoke';
const A_X = 80;
const A_Y = 40;
const B_X = 240;
const B_Y = 40;
const W = 100;
const H = 40;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
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
 * @param {Clutter.Stage} stage
 * @param {Clutter.Actor} want
 * @param {string} label
 */
function assertKeyFocus(stage, want, label) {
	const got = stage.get_key_focus();
	smokeLog(label + ' key_focus=' + (got ? got.get_name() : 'null'));
	if (got !== want) {
		throw new Error(
			'focus-smoke: expected key_focus ' + want.get_name()
			+ ' after ' + label + ', got '
			+ (got ? got.get_name() : 'null'));
	}
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null) {
		throw new Error('focus-smoke: stage is null');
	}

	const fm = globalObj.focus_manager;
	if (fm == null) {
		throw new Error('focus-smoke: focus_manager is null');
	}
	smokeLog('focus_manager ok');

	const Focusish = GObject.registerClass(
	class Focusish extends St.Widget {
		vfunc_event(event) {
			const t = event.type();
			if (t === Clutter.EventType.BUTTON_PRESS
					|| t === Clutter.EventType.TOUCH_BEGIN) {
				smokeLog('vfunc_event grab ' + this.get_name());
				this.grab_key_focus();
				return Clutter.EVENT_STOP;
			}
			return Clutter.EVENT_PROPAGATE;
		}
	});

	const a = new Focusish({
		name: 'focus-smoke-a',
		reactive: true,
		can_focus: true,
	});
	a.set_position(A_X, A_Y);
	a.set_size(W, H);
	a.set_style('background-color: #3498db;');
	stage.add_child(a);

	const b = new Focusish({
		name: 'focus-smoke-b',
		reactive: true,
		can_focus: true,
	});
	b.set_position(B_X, B_Y);
	b.set_size(W, H);
	b.set_style('background-color: #e67e22;');
	stage.add_child(b);

	fm.add_group(a);
	fm.add_group(b);
	a.show();
	b.show();
	smokeLog('widgets on stage');

	smokeLog('fire_button_press A');
	globalObj.fire_button_press(a);
	waitMs(50);
	assertKeyFocus(stage, a, 'click-A');

	smokeLog('fire_button_press B');
	globalObj.fire_button_press(b);
	waitMs(50);
	assertKeyFocus(stage, b, 'click-B');

	smokeLog('ok');
}

main();
