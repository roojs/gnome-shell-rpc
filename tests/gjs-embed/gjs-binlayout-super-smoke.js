/**
 * GJS subclass of Clutter.BinLayout / BoxLayout — super.vfunc_* must run
 * stock C preferred/allocate (FreezableBinLayout / CalendarColumnLayout
 * in dateMenu.js call super).
 *
 * If super returns 0×0 or no-ops allocate, BoxPointer natural width
 * collapses or freezes to a prior stage-sized box.
 *
 *   GI_META_SMOKE=gjs-binlayout-super-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * See docs/bugs/2026-09-16-chrome-panel-menus-overlay.md
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'gjs-binlayout-super-smoke';
const CHILD_W = 120;
const CHILD_H = 80;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * @param {boolean} ok
 * @param {string} label
 * @param {string} [detail]
 */
function assert(ok, label, detail) {
	if (ok)
		smokeLog('PASS ' + label + (detail ? ' ' + detail : ''));
	else
		smokeLog('FAIL ' + label + (detail ? ' ' + detail : ''));
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null)
		throw new Error(SMOKE_DOMAIN + ': stage is null');

	/* A — plain Clutter.BinLayout (leased) on St.Widget packs child. */
	{
		const actor = new St.Widget({name: 'plain-bin'});
		const child = new St.Widget({
			name: 'plain-bin-child',
			width: CHILD_W,
			height: CHILD_H,
		});
		actor.add_child(child);
		actor.layout_manager = new Clutter.BinLayout();
		stage.add_child(actor);
		actor.show();
		const [minW, natW] = actor.get_preferred_width(-1);
		const [minH, natH] = actor.get_preferred_height(-1);
		smokeLog(`A plain BinLayout preferred ${minW}x${minH} nat ${natW}x${natH}`);
		assert(natW >= CHILD_W - 1 && natH >= CHILD_H - 1, 'A',
			`nat>=${CHILD_W}x${CHILD_H}`);
	}

	/*
	 * B — FreezableBinLayout shape: GJS extends BinLayout, preferred
	 * delegates to super.vfunc_get_preferred_width (stock C BinLayout).
	 */
	const SuperBinLayout = GObject.registerClass(
	class SuperBinLayout extends Clutter.BinLayout {
		vfunc_get_preferred_width(container, forHeight) {
			return super.vfunc_get_preferred_width(container, forHeight);
		}

		vfunc_get_preferred_height(container, forWidth) {
			return super.vfunc_get_preferred_height(container, forWidth);
		}

		vfunc_allocate(container, box) {
			super.vfunc_allocate(container, box);
		}
	});

	{
		const actor = new St.Widget({name: 'super-bin'});
		const child = new St.Widget({
			name: 'super-bin-child',
			width: CHILD_W,
			height: CHILD_H,
		});
		actor.add_child(child);
		actor.layout_manager = new SuperBinLayout();
		stage.add_child(actor);
		actor.show();
		let minW = 0, natW = 0, minH = 0, natH = 0;
		try {
			[minW, natW] = actor.get_preferred_width(-1);
			[minH, natH] = actor.get_preferred_height(-1);
		} catch (e) {
			smokeLog('B preferred threw ' + e);
		}
		smokeLog(`B GJS-BinLayout super preferred ${minW}x${minH} nat ${natW}x${natH}`);
		assert(natW >= CHILD_W - 1 && natH >= CHILD_H - 1, 'B',
			`super.vfunc preferred nat>=${CHILD_W}x${CHILD_H} (not 0)`);

		try {
			const box = new Clutter.ActorBox();
			box.init_rect(0, 0, 200, 100);
			actor.allocate(box);
			const [cw, ch] = child.get_size();
			smokeLog(`B after allocate child ${cw}x${ch}`);
			assert(cw >= CHILD_W - 1 && ch >= CHILD_H - 1, 'B',
				`super.vfunc_allocate packs child`);
		} catch (e) {
			assert(false, 'B', 'allocate threw ' + e);
		}
	}

	/*
	 * C — CalendarColumnLayout shape: GJS extends BoxLayout, preferred
	 * from children; allocate via super.vfunc_allocate (stock C BoxLayout).
	 */
	const SuperBoxLayout = GObject.registerClass(
	class SuperBoxLayout extends Clutter.BoxLayout {
		vfunc_get_preferred_width(container, forHeight) {
			const kids = container.get_children();
			if (kids.length === 0)
				return super.vfunc_get_preferred_width(container, forHeight);
			return kids.reduce(([minAcc, natAcc], child) => {
				const [min, nat] = child.get_preferred_width(forHeight);
				return [Math.max(minAcc, min), Math.max(natAcc, nat)];
			}, [0, 0]);
		}

		vfunc_allocate(container, box) {
			super.vfunc_allocate(container, box);
		}
	});

	{
		const actor = new St.Widget({name: 'super-box'});
		actor.layout_manager = new SuperBoxLayout({
			orientation: Clutter.Orientation.VERTICAL,
		});
		const child = new St.Widget({
			name: 'super-box-child',
			width: CHILD_W,
			height: CHILD_H,
		});
		actor.add_child(child);
		stage.add_child(actor);
		actor.show();
		const [minW, natW] = actor.get_preferred_width(-1);
		smokeLog(`C GJS-BoxLayout preferred width min=${minW} nat=${natW}`);
		assert(natW >= CHILD_W - 1, 'C', `preferred natW>=${CHILD_W}`);

		try {
			const box = new Clutter.ActorBox();
			box.init_rect(0, 0, 200, 100);
			actor.allocate(box);
			const [cx, cy] = child.get_position();
			const [cw, ch] = child.get_size();
			smokeLog(`C after allocate child @${cx},${cy} ${cw}x${ch}`);
			assert(cw >= CHILD_W - 1 && ch >= CHILD_H - 1, 'C',
				`super.vfunc_allocate packs child`);
		} catch (e) {
			assert(false, 'C', 'allocate threw ' + e);
		}
	}

	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
		smokeLog('done');
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
