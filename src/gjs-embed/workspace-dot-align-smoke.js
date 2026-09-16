/**
 * Pin — public Clutter.Actor.allocate applies y-align (stock GIR).
 *
 * docs/clutter-layout-allocate.md Flow 2. Stock WorkspaceDot:
 * set_allocation(self) then _dot.allocate(full box) with y_align CENTER.
 * clutter_actor_allocate must place the preferred-size child in the extra
 * space. This smoke does not invent that rule.
 *
 *   GI_META_SMOKE=workspace-dot-align-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Prove-only — does not patch stubs/Helpers.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'workspace-dot-align-smoke';
const PANEL_H = 32;
const DOT_W = 12;
const DOT_H = 8;
const BAR_W = 80;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * @param {Clutter.Actor} actor
 * @param {Clutter.Actor} parent
 */
function midDy(actor, parent) {
	const [ax, ay] = actor.get_transformed_position();
	const [aw, ah] = actor.get_transformed_size();
	const [px, py] = parent.get_transformed_position();
	const [pw, ph] = parent.get_transformed_size();
	const dy = (ay + ah / 2) - (py + ph / 2);
	return {
		geom: `${ax.toFixed(0)},${ay.toFixed(0)} ${aw.toFixed(0)}x${ah.toFixed(0)}`,
		parent: `${px.toFixed(0)},${py.toFixed(0)} ${pw.toFixed(0)}x${ph.toFixed(0)}`,
		dy,
	};
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null) {
		throw new Error('workspace-dot-align-smoke: stage is null');
	}

	/* ---- A: St.BoxLayout + y_align CENTER child (panelLeft / indicators) ---- */
	const boxA = new St.BoxLayout({
		name: 'workspace-dot-align-A',
		vertical: false,
	});
	boxA.set_size(BAR_W, PANEL_H);
	const childA = new St.Widget({
		name: 'workspace-dot-align-A-child',
		y_align: Clutter.ActorAlign.CENTER,
		x_align: Clutter.ActorAlign.START,
	});
	childA.set_size(DOT_W, DOT_H);
	boxA.add_child(childA);
	stage.add_child(boxA);
	boxA.set_position(10, 10);
	boxA.show();
	childA.show();

	/* ---- B: stock panel item — St.Bin({child}) ---- */
	const childB = new St.Widget({
		name: 'workspace-dot-align-B-child',
		y_align: Clutter.ActorAlign.CENTER,
	});
	childB.set_size(DOT_W, DOT_H);
	const binB = new St.Bin({
		name: 'workspace-dot-align-B',
		child: childB,
	});
	binB.set_size(BAR_W, PANEL_H);
	stage.add_child(binB);
	binB.set_position(10, 50);
	binB.show();
	childB.show();

	/* ---- C: stock WorkspaceDot — extends Clutter.Actor, not St.Widget ----
	 * panel.js WorkspaceDot.vfunc_allocate: set_allocation then
	 * _dot.allocate(full box) with y_align CENTER. St.Widget Dotish was a
	 * false green (Helper-Actor hooks); Clutter.Actor is the real shape. */
	const Dotish = GObject.registerClass(
	class Dotish extends Clutter.Actor {
		vfunc_get_preferred_width(_forHeight) {
			return [DOT_W, DOT_W];
		}

		vfunc_get_preferred_height(_forWidth) {
			return [DOT_H, DOT_H];
		}

		vfunc_allocate(box) {
			this.set_allocation(box);
			const inner = this.get_first_child();
			if (!inner)
				return;
			box.set_origin(0, 0);
			inner.allocate(box);
		}
	});
	const outerC = new Dotish({
		name: 'workspace-dot-align-C',
	});
	const innerC = new St.Widget({
		name: 'workspace-dot-align-C-dot',
		style_class: 'workspace-dot',
		y_align: Clutter.ActorAlign.CENTER,
		x_align: Clutter.ActorAlign.CENTER,
		request_mode: Clutter.RequestMode.WIDTH_FOR_HEIGHT,
	});
	innerC.set_size(DOT_W, DOT_H);
	smokeLog('C outer type=' + outerC.constructor.$gtype.name
		+ ' inner y_align=' + innerC.y_align
		+ ' (CENTER=' + Clutter.ActorAlign.CENTER + ')');
	outerC.add_child(innerC);
	const boxC = new St.BoxLayout({
		name: 'workspace-dot-align-C-bar',
	});
	boxC.set_size(BAR_W, PANEL_H);
	boxC.add_child(outerC);
	stage.add_child(boxC);
	boxC.set_position(10, 90);
	boxC.show();
	outerC.show();
	innerC.show();

	const loop = new GLib.MainLoop(null, false);
	let tries = 0;
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
		tries++;
		if (tries === 3) {
			const alloc = new Clutter.ActorBox();
			alloc.init_rect(10, 10, BAR_W, PANEL_H);
			boxA.allocate(alloc);
			alloc.init_rect(10, 50, BAR_W, PANEL_H);
			binB.allocate(alloc);
			alloc.init_rect(10, 90, BAR_W, PANEL_H);
			boxC.allocate(alloc);
			smokeLog('forced allocate');
		}

		const a = midDy(childA, boxA);
		const b = midDy(childB, binB);
		const c = midDy(innerC, boxC);
		smokeLog(`poll${tries} A child@${a.geom} bar@${a.parent} midDy=${a.dy.toFixed(1)}`);
		smokeLog(`poll${tries} B child@${b.geom} bin@${b.parent} midDy=${b.dy.toFixed(1)}`);
		smokeLog(`poll${tries} C inner@${c.geom} bar@${c.parent} midDy=${c.dy.toFixed(1)}`);

		if (tries < 8) {
			return GLib.SOURCE_CONTINUE;
		}

		let failed = false;
		if (Math.abs(a.dy) > 2) {
			smokeLog(`FAIL A boxlayout-y-align-center midDy=${a.dy.toFixed(1)}`);
			failed = true;
		} else {
			smokeLog('A PASS boxlayout-y-align-center');
		}
		if (Math.abs(b.dy) > 2) {
			smokeLog(`FAIL B st-bin-child-centre midDy=${b.dy.toFixed(1)}`);
			failed = true;
		} else {
			smokeLog('B PASS st-bin-child-centre');
		}
		if (Math.abs(c.dy) > 2) {
			smokeLog(`FAIL C workspacedot-allocate-fullbox midDy=${c.dy.toFixed(1)}`);
			failed = true;
		} else {
			smokeLog('C PASS workspacedot-allocate-fullbox');
		}
		if (!failed)
			smokeLog('PASS');
		smokeLog('done');
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
