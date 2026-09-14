/**
 * 0.8 Phase B3 — pointer → chrome via Actor.event Live.Hook
 * (fire_button_press → event Live.Hook; seat/pick is pointer_click).
 *
 *   GI_META_SMOKE=panel-click-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
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
			const t = event.type();
			smokeLog('vfunc_event type=' + t);
			if (t === Clutter.EventType.BUTTON_PRESS
					|| t === Clutter.EventType.TOUCH_BEGIN) {
				sawEvent = true;
				smokeLog('clicked');
			}
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
