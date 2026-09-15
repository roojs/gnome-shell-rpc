/**
 * Debug smoke — recreate layout_manager / allocate CRITICAL (0.8 chrome).
 *
 *   GI_META_SMOKE=layout-allocate-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Does not "fix" anything. Logs steps; asserts GJS LayoutManager Class
 * vfunc actually ran when Actor.allocate takes the local GJS path.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'layout-allocate-smoke';

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
		throw new Error('layout-allocate-smoke: stage is null');
	}

	let allocateHits = 0;
	const GjsLayout = GObject.registerClass(
	class GjsLayout extends Clutter.LayoutManager {
		vfunc_get_preferred_width() {
			return [100, 100];
		}

		vfunc_get_preferred_height() {
			return [40, 40];
		}

		vfunc_allocate(container, box) {
			allocateHits++;
			smokeLog('GjsLayout.vfunc_allocate '
				+ box.get_x() + ',' + box.get_y()
				+ ' ' + box.get_width() + 'x' + box.get_height());
			container.set_allocation(box);
		}
	});

	smokeLog('step1: St.Widget no layout_manager, allocate');
	const bare = new St.Widget({
		name: 'layout-smoke-bare',
		reactive: true,
	});
	bare.set_size(100, 40);
	stage.add_child(bare);
	bare.show();
	try {
		const box = new Clutter.ActorBox();
		box.init_rect(0, 0, 100, 40);
		bare.allocate(box);
		smokeLog('step1: allocate returned');
	} catch (e) {
		smokeLog('step1: threw ' + e);
	}

	smokeLog('step2: St.Widget + GjsLayout, allocate');
	allocateHits = 0;
	const withLm = new St.Widget({
		name: 'layout-smoke-gjs-lm',
		reactive: true,
	});
	withLm.set_size(100, 40);
	withLm.layout_manager = new GjsLayout();
	stage.add_child(withLm);
	withLm.show();
	try {
		const box = new Clutter.ActorBox();
		box.init_rect(10, 10, 110, 50);
		withLm.allocate(box);
		smokeLog('step2: allocate returned hits=' + allocateHits);
		if (allocateHits < 1) {
			smokeLog('FAIL step2: GjsLayout.vfunc_allocate not called '
				+ '(GJS LM clear+RPC allocate → CRITICAL; JS vfunc never ran)');
		}
	} catch (e) {
		smokeLog('step2: threw ' + e);
	}

	smokeLog('step3: GObject St.Widget subclass + GjsLayout');
	allocateHits = 0;
	const Sub = GObject.registerClass(
	class Sub extends St.Widget {
	});
	const sub = new Sub({
		name: 'layout-smoke-sub',
		reactive: true,
	});
	sub.set_size(100, 40);
	sub.layout_manager = new GjsLayout();
	stage.add_child(sub);
	sub.show();
	try {
		const box = new Clutter.ActorBox();
		box.init_rect(20, 20, 120, 60);
		sub.allocate(box);
		smokeLog('step3: allocate returned hits=' + allocateHits);
		if (allocateHits < 1) {
			smokeLog('FAIL step3: GjsLayout.vfunc_allocate not called');
		}
	} catch (e) {
		smokeLog('step3: threw ' + e);
	}

	/*
	 * step4: layout_manager=null with no prior client manager is a no-op
	 * (must not clear compositor default). Explicit clear after a GJS LM:
	 */
	smokeLog('step4: GjsLayout then layout_manager=null (expect CRITICAL)');
	const cleared = new St.BoxLayout({
		name: 'layout-smoke-cleared',
		reactive: true,
	});
	cleared.set_size(100, 40);
	stage.add_child(cleared);
	cleared.show();
	cleared.layout_manager = new GjsLayout();
	cleared.layout_manager = null;
	try {
		const box = new Clutter.ActorBox();
		box.init_rect(0, 0, 100, 40);
		cleared.allocate(box);
		smokeLog('step4: allocate returned (check tee for CLUTTER_IS_LAYOUT_MANAGER)');
	} catch (e) {
		smokeLog('step4: threw ' + e);
	}

	/*
	 * step5: PanelMenu ButtonBox shape — GJS Widget vfunc_allocate →
	 * child St.BoxLayout.allocate (nest CRITICAL parent was PanelMenuButton).
	 */
	smokeLog('step5: GJS ButtonBox-like + St.BoxLayout child allocate');
	const ButtonBox = GObject.registerClass(
	class ButtonBox extends St.Widget {
		vfunc_allocate(box) {
			this.set_allocation(box);
			const child = this.get_first_child();
			if (child)
				child.allocate(box);
		}
	});
	const bb = new ButtonBox({name: 'layout-smoke-buttonbox'});
	const bbChild = new St.BoxLayout({name: 'layout-smoke-bb-child'});
	bbChild.set_size(80, 24);
	bb.add_child(bbChild);
	stage.add_child(bb);
	bb.show();
	try {
		const box = new Clutter.ActorBox();
		box.init_rect(0, 0, 100, 32);
		bb.allocate(box);
		smokeLog('step5: allocate returned');
	} catch (e) {
		smokeLog('step5: threw ' + e);
	}

	/* step6: nest shape — St.BoxLayout.new + set_orientation + allocate */
	smokeLog('step6: St.BoxLayout set_orientation then allocate');
	const orient = new St.BoxLayout({name: 'layout-smoke-orient'});
	orient.set_orientation(Clutter.Orientation.HORIZONTAL);
	const lab = new St.Label({text: 'x'});
	orient.add_child(lab);
	stage.add_child(orient);
	orient.show();
	try {
		const box = new Clutter.ActorBox();
		box.init_rect(0, 0, 120, 32);
		orient.allocate(box);
		smokeLog('step6: allocate returned');
	} catch (e) {
		smokeLog('step6: threw ' + e);
	}

	/* Give compositor a beat so tee can show any delayed CRITICAL. */
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
		smokeLog('done');
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
