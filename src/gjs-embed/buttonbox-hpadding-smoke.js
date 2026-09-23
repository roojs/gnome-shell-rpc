/**
 * Pin — PanelMenu.ButtonBox caches -natural-hpadding on style-changed.
 *
 * Stock panelMenu.js: connect('style-changed') → get_length('-natural-hpadding').
 * Theme lengths RPC fine; without client style-changed, _natHPadding stays 0
 * and workspace dots sit tight-left (no hpadding in allocate).
 *
 *   GI_META_SMOKE=buttonbox-hpadding-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Prove-only — does not patch stubs/Helpers.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'buttonbox-hpadding-smoke';
const WANT_NAT = 12;
const WANT_MIN = 6;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

const ButtonBoxish = GObject.registerClass(
class ButtonBoxish extends St.Widget {
	_init(params) {
		super._init({
			style_class: 'panel-button',
			x_expand: true,
			y_expand: true,
			...params,
		});
		this._minHPadding = this._natHPadding = 0.0;
		this._vfuncStyleEntered = 0;
		this._vfuncStyleCompleted = 0;
		this._vfuncStyleError = '';
		this.connect('style-changed', this._onStyleChanged.bind(this));
	}

	vfunc_style_changed() {
		this._vfuncStyleEntered++;
		try {
			super.vfunc_style_changed();
			this._vfuncStyleCompleted++;
		} catch (e) {
			this._vfuncStyleError = String(e);
		}
	}

	_onStyleChanged(actor) {
		const themeNode = actor.get_theme_node();
		this._minHPadding = themeNode.get_length('-minimum-hpadding');
		this._natHPadding = themeNode.get_length('-natural-hpadding');
	}
});

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null) {
		throw new Error(SMOKE_DOMAIN + ': stage is null');
	}

	const btn = new ButtonBoxish({name: 'buttonbox-hpadding-smoke'});
	const child = new St.Widget({name: 'buttonbox-hpadding-child'});
	child.set_size(16, 16);
	btn.add_child(child);
	stage.add_child(btn);
	btn.set_position(40, 40);
	btn.set_size(80, 32);
	btn.show();
	child.show();

	/* Inline CSS — same properties ButtonBox reads from panel-button theme. */
	btn.set_style(
		`-minimum-hpadding: ${WANT_MIN}px; -natural-hpadding: ${WANT_NAT}px;`);
	btn.ensure_style();

	const tn = btn.get_theme_node();
	const themeMin = tn.get_length('-minimum-hpadding');
	const themeNat = tn.get_length('-natural-hpadding');
	smokeLog(`theme min=${themeMin} nat=${themeNat} ` +
		`_minHPadding=${btn._minHPadding} _natHPadding=${btn._natHPadding}`);

	let failed = false;
	if (themeNat < WANT_NAT) {
		smokeLog(`FAIL theme-nat-missing want>=${WANT_NAT} got=${themeNat}`);
		failed = true;
	}
	if (btn._natHPadding < WANT_NAT) {
		smokeLog(`FAIL nat-hpadding-cache want>=${WANT_NAT} ` +
			`got=${btn._natHPadding} (style-changed did not update GJS)`);
		failed = true;
	}
	if (btn._minHPadding < WANT_MIN) {
		smokeLog(`FAIL min-hpadding-cache want>=${WANT_MIN} ` +
			`got=${btn._minHPadding}`);
		failed = true;
	}
	if (btn._vfuncStyleEntered < 1 || btn._vfuncStyleCompleted < 1) {
		smokeLog(`FAIL vfunc_style_changed entered=${btn._vfuncStyleEntered} ` +
			`completed=${btn._vfuncStyleCompleted} error=${btn._vfuncStyleError}`);
		failed = true;
	}

	if (failed) {
		smokeLog('FAIL');
		return;
	}
	smokeLog(`ok nat=${btn._natHPadding} min=${btn._minHPadding}`);
}

main();
