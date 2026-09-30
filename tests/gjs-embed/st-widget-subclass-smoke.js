/**
 * 0.7.6 Phase D — St.Widget lease-on-construct + GJS subclass + add_child
 * (layout.js UiActor / overviewGroup path).
 *
 * Manual (bypass libshell bootstrap — use gjs-embed):
 *   dbus-run-session bash -c '
 *     ./build/src/mutter-rpc --wayland --nested &
 *     sleep 1
 *     MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)
 *     MUTTER_RPC_SOCKET=$XDG_RUNTIME_DIR/mutter-rpc.sock \
 *     GI_TYPELIB_PATH=./build/src:$MUTTER_TL LD_LIBRARY_PATH=./build/src \
 *       ./build/src/gjs-embed --debug src/gjs-embed/st-widget-subclass-smoke.js
 *   '
 *
 * Nested via gnome-shell-rpc (needs 0.7.7 thin host past Shell.Global):
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
	try {
		actor.get_transformed_position();
	} catch (e) {
		throw new Error(`${label}: get_transformed_position failed: ${e}`);
	}
	smokeLog(`${label}: get_transformed_position ok`);
}

/**
 * layout.js tree without global.stage (Shell host is 0.7.7):
 *   uiGroup = new UiActor({name: 'uiGroup'});
 *   uiGroup.add_child(overviewGroup);
 */
function assertLeasedTree(UiActor) {
	smokeLog('UiActor({name}) + add_child(overviewGroup)');
	const uiGroup = new UiActor({name: 'uiGroup'});
	assertRpcActor(uiGroup, 'uiGroup');
	uiGroup.set_name('uiGroup');
	smokeLog('uiGroup.set_name ok');

	const overviewGroup = new St.Widget({
		name: 'overviewGroup',
		layout_manager: new Clutter.BinLayout(),
		x_expand: true,
		y_expand: true,
	});
	assertRpcActor(overviewGroup, 'overviewGroup');
	uiGroup.add_child(overviewGroup);
	smokeLog('uiGroup.add_child(overviewGroup) ok');
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

	assertLeasedTree(UiActor);

	smokeLog('ok');
}

main();
