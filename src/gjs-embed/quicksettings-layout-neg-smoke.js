/**
 * Pin — QuickSettingsLayout empty grid + row-spacing → preferred height -12.
 *
 * Stock quickSettings.js:
 *   spacing = (rows.length - 1) * this.row_spacing
 * With only the overlay/placeholder child, rows=[], spacing = -row_spacing.
 * Theme spacing-rows is 12px → min/nat = -12 → ClutterBoxLayout aborts
 * (mutter ec=133). Surfaced after style-changed relay set rowSpacing.
 *
 *   GI_META_SMOKE=quicksettings-layout-neg-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Prove-only — does not patch stubs/Helpers.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'quicksettings-layout-neg-smoke';
const ROW_SPACING = 12;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/* Stock QuickSettingsLayout preferred-height shape (overlay skipped in rows). */
const QSLayoutish = GObject.registerClass({
	Properties: {
		'row-spacing': GObject.ParamSpec.int(
			'row-spacing', null, null,
			GObject.ParamFlags.READWRITE,
			0, GLib.MAXINT32, 0),
	},
}, class QSLayoutish extends Clutter.LayoutManager {
	_init(overlay, params) {
		super._init(params);
		this._overlay = overlay;
	}

	vfunc_get_preferred_width(_container, _forHeight) {
		return [0, 0];
	}

	vfunc_get_preferred_height(container, _forWidth) {
		const rows = [];
		for (const child of container) {
			if (!child.visible)
				continue;
			if (child === this._overlay)
				continue;
			rows.push([child]);
		}

		let [minHeight, natHeight] = this._overlay.get_preferred_height(-1);

		const spacing = (rows.length - 1) * this.row_spacing;
		minHeight += spacing;
		natHeight += spacing;

		return [minHeight, natHeight];
	}
});

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null)
		throw new Error(SMOKE_DOMAIN + ': stage is null');

	const overlay = new Clutter.Actor({name: 'qs-smoke-overlay'});
	const grid = new St.Widget({
		name: 'qs-smoke-grid',
		layout_manager: new QSLayoutish(overlay, {row_spacing: ROW_SPACING}),
	});
	grid.add_child(overlay);
	grid.layout_manager.row_spacing = ROW_SPACING;
	stage.add_child(grid);
	grid.show();

	const [minH, natH] = grid.get_preferred_height(182);
	smokeLog(`preferred height min=${minH} nat=${natH} row_spacing=${ROW_SPACING} (stock empty-rows formula)`);

	if (minH < 0 || natH < 0) {
		smokeLog(`FAIL negative-preferred want>=0 got min=${minH} nat=${natH}`);
		smokeLog('FAIL');
		return;
	}
	smokeLog(`ok min=${minH} nat=${natH}`);
}

main();
