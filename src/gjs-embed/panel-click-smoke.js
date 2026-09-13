/**
 * 0.8 Phase B3 — pointer → chrome via Actor.event Live.Hook
 * (VfuncRelay name-keyed; PanelMenu.Button uses vfunc_event).
 *
 *   GI_META_SMOKE=panel-click-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Places a reactive St.Widget with vfunc_event on the stage, then
 * Helper-Actor.fire_button_press (relay prove; hit-test is pointer_click).
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'panel-click-smoke';
const BTN_X = 80;
const BTN_Y = 24;
const BTN_W = 120;
const BTN_H = 40;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null) {
		throw new Error('panel-click-smoke: stage is null');
	}

	let sawEvent = false;
	const Panelish = GObject.registerClass(
	class Panelish extends St.Widget {
		vfunc_event(event) {
			/* Typelib still lists Event as union (stock GIR); our stub is
			 * GObject — avoid Event methods until typelib matches. */
			sawEvent = true;
			smokeLog('clicked');
			return Clutter.EVENT_STOP;
		}
	});

	const btn = new Panelish({
		name: 'panel-click-smoke-btn',
		reactive: true,
		can_focus: true,
	});
	btn.set_position(BTN_X, BTN_Y);
	btn.set_size(BTN_W, BTN_H);
	btn.set_style('background-color: #2ecc71;');
	stage.add_child(btn);
	btn.show();
	smokeLog('button on stage at ' + BTN_X + ',' + BTN_Y);

	smokeLog('fire_button_press');
	globalObj.fire_button_press(btn);

	if (!sawEvent) {
		throw new Error('panel-click-smoke: no vfunc_event after fire_button_press');
	}
	smokeLog('ok');
}

main();
