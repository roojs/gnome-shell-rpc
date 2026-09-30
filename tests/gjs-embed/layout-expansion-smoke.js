/**
 * Smoke — St.Widget.find_property('@layout.expansion').
 *
 * MessageTray banner expand eases that name. A null pspec throws in
 * environment.js while MessageTray._updatingState is set.
 *
 *   GI_META_SMOKE=layout-expansion-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'layout-expansion-smoke';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

const ExpanderLayout = GObject.registerClass({
	Properties: {
		'expansion': GObject.ParamSpec.double(
			'expansion', null, null,
			GObject.ParamFlags.READWRITE,
			0, 1, 0),
	},
}, class ExpanderLayout extends Clutter.BinLayout {
	_init(params = {}) {
		super._init(params);
		this._expansion = 0;
	}

	get expansion() {
		return this._expansion;
	}

	set expansion(v) {
		this._expansion = v;
	}
});

function main() {
	const globalObj = Shell.Global.get();
	if (globalObj == null) {
		throw new Error('layout-expansion-smoke: Global is null');
	}

	const layout = new ExpanderLayout();
	const bin = new St.Bin({ layout_manager: layout });
	const pspec = bin.find_property('@layout.expansion');
	if (pspec == null) {
		smokeLog('FAIL: find_property(@layout.expansion) returned null');
		smokeLog('done');
		return;
	}
	if (pspec.value_type !== GObject.TYPE_DOUBLE) {
		smokeLog(`FAIL: value_type=${pspec.value_type}`);
		smokeLog('done');
		return;
	}

	const missing = bin.find_property('@layout.not-a-property');
	if (missing != null) {
		smokeLog('FAIL: missing layout property returned a pspec');
		smokeLog('done');
		return;
	}

	const visible = bin.find_property('visible');
	if (visible == null) {
		smokeLog('FAIL: find_property(visible) returned null');
		smokeLog('done');
		return;
	}

	smokeLog('PASS');
	smokeLog('done');
}

main();
