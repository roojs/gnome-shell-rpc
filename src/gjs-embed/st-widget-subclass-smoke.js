/**
 * St.Widget lease-on-construct + GJS subclass (layout.js UiActor path).
 *
 * Nested:
 *   GI_META_SMOKE=st-widget-subclass-smoke.js \
 *     dbus-run-session ./build/src/mutter-rpc --wayland --nested
 */
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const St = imports.gi.St;
const GObject = imports.gi.GObject;
const Clutter = imports.gi.Clutter;

const SMOKE_DOMAIN = 'st-widget-subclass-smoke';

function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * Exercise RPC wiring — Runtime GLib.errors when rpc_lid is missing.
 */
function assertRpcActor(actor, label) {
	if (!actor || typeof actor !== 'object') {
		throw new Error(`${label}: not an object`);
	}
	const [ok, x, y] = actor.get_transformed_position();
	smokeLog(`${label}: get_transformed_position ok=(${ok}, ${x}, ${y})`);
}

function main() {
	smokeLog('new St.Widget()');
	const widget = new St.Widget();
	assertRpcActor(widget, 'St.Widget');

	smokeLog('registerClass UiActor extends St.Widget');
	const UiActor = GObject.registerClass(
	class UiActor extends St.Widget {
		_init(params) {
			super._init(params);
		}
	});
	const ui = new UiActor();
	assertRpcActor(ui, 'UiActor');

	smokeLog('new St.BoxLayout()');
	const box = new St.BoxLayout();
	assertRpcActor(box, 'St.BoxLayout');

	smokeLog('ok');
}

main();
