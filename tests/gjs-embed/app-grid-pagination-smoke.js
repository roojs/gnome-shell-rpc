/**
 * AppGrid extends St.Viewport and IconGrid.goToPage() animates the
 * viewport's own hadjustment. Require a subclass scroll child to expose
 * the adjustments installed by St.ScrollView.
 *
 * Pass: `app-grid-pagination-smoke: ok`
 * Fail: `app-grid-pagination-smoke: miss adjustments ...`
 *
 *   GI_META_SMOKE=app-grid-pagination-smoke GSR_WESTON_PIXMAN=1 \
 *   ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Clutter = '16';
imports.gi.versions.GLib = '2.0';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';

const {Clutter, GLib, GObject, Shell, St} = imports.gi;

const SMOKE = 'app-grid-pagination-smoke';

function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.stage;
	const proveFix = GLib.getenv('GSR_PAGE_FIX') === '1';
	const ViewportSubclass = GObject.registerClass(
	class ViewportSubclass extends St.Viewport {
		_init(params = {}) {
			super._init(params);
			this._clientHAdjustment = null;
			this._clientVAdjustment = null;
		}

		get hadjustment() {
			return proveFix ? this._clientHAdjustment : super.hadjustment;
		}

		set hadjustment(adjustment) {
			if (proveFix)
				this._clientHAdjustment = adjustment;
			else
				super.hadjustment = adjustment;
		}

		get vadjustment() {
			return proveFix ? this._clientVAdjustment : super.vadjustment;
		}

		set vadjustment(adjustment) {
			if (proveFix)
				this._clientVAdjustment = adjustment;
			else
				super.vadjustment = adjustment;
		}

		set_adjustments(hadjustment, vadjustment) {
			this.hadjustment = hadjustment;
			this.vadjustment = vadjustment;
		}
	});
	const viewport = new ViewportSubclass({
		x_expand: true,
		y_expand: true,
	});
	const scroll = new St.ScrollView({
		width: 800,
		height: 315,
		child: viewport,
	});
	stage.add_child(scroll);
	scroll.show();
	if (proveFix)
		viewport.set_adjustments(scroll.hadjustment, scroll.vadjustment);

	const box = new Clutter.ActorBox();
	box.init_rect(0, 0, 800, 315);
	scroll.allocate(box);

	const viewportH = viewport.hadjustment;
	const viewportV = viewport.vadjustment;
	const scrollH = scroll.hadjustment;
	const scrollV = scroll.vadjustment;
	smokeLog('adjustments viewport='
		+ (viewportH == null ? 'null' : 'set') + '/'
		+ (viewportV == null ? 'null' : 'set')
		+ ' scroll='
		+ (scrollH == null ? 'null' : 'set') + '/'
		+ (scrollV == null ? 'null' : 'set'));

	if (viewportH == null || viewportV == null)
		smokeLog('miss adjustments');
	else if (viewportH !== scrollH || viewportV !== scrollV)
		smokeLog('miss adjustment-identity');
	else
		smokeLog('ok');
	globalObj.context.terminate();
}

main();
