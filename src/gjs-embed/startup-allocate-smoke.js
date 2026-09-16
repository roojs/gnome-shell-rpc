/**
 * Chrome §3 pin — GJS LayoutManager ensureAllocation pattern
 * (overviewControls ControlsLayout.ensureAllocation).
 *
 * Stock runStartupAnimation awaits ensureAllocation() before dash.ease;
 * if layout_changed never yields allocate → _runPostAllocation, startup
 * never clears layoutManager._startingUp (grey cover + click block).
 *
 *   GI_META_SMOKE=startup-allocate-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * See docs/bugs/2026-09-16-chrome-panel-menus-overlay.md
 *
 * Prove-only — does not patch stubs/Helpers.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'startup-allocate-smoke';
const WAIT_MS = 2000;

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE_DOMAIN + ': ' + message);
}

/**
 * @param {number} ms
 */
function waitMs(ms) {
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

function main() {
	const globalObj = Shell.Global.get();
	const stage = globalObj.get_stage();
	if (stage == null) {
		throw new Error('startup-allocate-smoke: stage is null');
	}

	const postAllocationCallbacks = [];
	let allocateHits = 0;
	let layoutChangedSignals = 0;
	let queueRelayoutFromSignal = 0;

	const ControlsishLayout = GObject.registerClass(
	class ControlsishLayout extends Clutter.LayoutManager {
		vfunc_get_preferred_width(_container, _forHeight) {
			return [100, 100];
		}

		vfunc_get_preferred_height(_container, _forWidth) {
			return [40, 40];
		}

		vfunc_allocate(container, box) {
			allocateHits++;
			smokeLog('vfunc_allocate hit=' + allocateHits
				+ ' box=' + box.get_width() + 'x' + box.get_height());
			container.set_allocation(box);
			/* Stock ControlsLayout._runPostAllocation */
			if (postAllocationCallbacks.length === 0)
				return;
			const cbs = postAllocationCallbacks.splice(0);
			smokeLog('flush postAllocationCallbacks n=' + cbs.length);
			cbs.forEach(cb => cb());
		}

		ensureAllocation() {
			this.layout_changed();
			return new Promise(
				resolve => postAllocationCallbacks.push(resolve));
		}
	});

	const lm = new ControlsishLayout();
	const actor = new St.Widget({
		name: 'startup-allocate-smoke-actor',
		reactive: true,
	});
	actor.set_size(100, 40);
	actor.layout_manager = lm;
	stage.add_child(actor);
	actor.show();

	/* Observe: does layout_changed() emit the GIR signal? */
	lm.connect('layout-changed', () => {
		layoutChangedSignals++;
		smokeLog('signal layout-changed n=' + layoutChangedSignals);
	});

	/* ---- A: stock ensureAllocation shape (no extra handlers) ---- */
	smokeLog('A ensureAllocation enter');
	let resolved = false;
	const pA = lm.ensureAllocation().then(() => {
		resolved = true;
		smokeLog('A ensureAllocation resolved');
	});
	waitMs(WAIT_MS);
	void pA;
	smokeLog('A after ' + WAIT_MS + 'ms resolved=' + resolved
		+ ' allocateHits=' + allocateHits
		+ ' pendingCbs=' + postAllocationCallbacks.length
		+ ' layoutChangedSignals=' + layoutChangedSignals);
	if (!resolved) {
		smokeLog('FAIL A ensureAllocation-never-resolved');
	} else {
		smokeLog('A PASS');
	}

	/* ---- B: stock-shaped signal → queue_relayout (what set_container
	 * connection does in-process). If still FAIL, break is queue_relayout
	 * not reaching GJS LM allocate — not merely missing connect. ---- */
	postAllocationCallbacks.length = 0;
	allocateHits = 0;
	resolved = false;
	const handlerId = lm.connect('layout-changed', () => {
		queueRelayoutFromSignal++;
		smokeLog('B signal→queue_relayout n=' + queueRelayoutFromSignal);
		actor.queue_relayout();
	});
	smokeLog('B ensureAllocation enter (signal→queue_relayout connected)');
	const pB = lm.ensureAllocation().then(() => {
		resolved = true;
		smokeLog('B ensureAllocation resolved');
	});
	waitMs(WAIT_MS);
	void pB;
	smokeLog('B after ' + WAIT_MS + 'ms resolved=' + resolved
		+ ' allocateHits=' + allocateHits
		+ ' pendingCbs=' + postAllocationCallbacks.length
		+ ' queueRelayoutFromSignal=' + queueRelayoutFromSignal);
	if (!resolved) {
		smokeLog('FAIL B signal-queue_relayout-no-allocate');
	}
	lm.disconnect(handlerId);

	/* ---- C: queue_relayout alone (no layout_changed) ---- */
	if (!resolved) {
		postAllocationCallbacks.push(() => {
			resolved = true;
			smokeLog('C callback resolved');
		});
		smokeLog('C actor.queue_relayout with pending callback');
		actor.queue_relayout();
		waitMs(WAIT_MS);
		smokeLog('C after ' + WAIT_MS + 'ms resolved=' + resolved
			+ ' allocateHits=' + allocateHits);
		if (!resolved)
			smokeLog('FAIL C queue_relayout-alone-no-allocate');
	}

	/* ---- D: direct allocate (known working path) ---- */
	if (!resolved) {
		try {
			const box = new Clutter.ActorBox();
			box.init_rect(0, 0, 100, 40);
			smokeLog('D actor.allocate direct');
			actor.allocate(box);
			/* Promise microtask may run after this line */
			waitMs(50);
			smokeLog('D after direct allocate resolved=' + resolved
				+ ' allocateHits=' + allocateHits
				+ ' pendingCbs=' + postAllocationCallbacks.length);
			if (allocateHits < 1)
				smokeLog('FAIL D direct-allocate-no-vfunc');
			else if (postAllocationCallbacks.length === 0 || resolved)
				smokeLog('D direct-allocate-vfunc-ok');
		} catch (e) {
			smokeLog('FAIL D direct allocate threw ' + e);
		}
	}

	if (resolved && allocateHits > 0
			&& layoutChangedSignals > 0) {
		/* Only PASS if A alone worked — otherwise keep FAIL summary. */
	}
	smokeLog('summary signals=' + layoutChangedSignals
		+ ' A/B/C need allocate-from-relayout; D proves vfunc works');

	/* ---- E: GJS Actor.allocate override — does compositor queue_relayout
	 * call back into client Actor.allocate hook? ---- */
	let actorVfuncHits = 0;
	let lmVfuncHits = 0;
	const postE = [];
	const LmE = GObject.registerClass(
	class LmE extends Clutter.LayoutManager {
		vfunc_get_preferred_width() {
			return [80, 80];
		}

		vfunc_get_preferred_height() {
			return [30, 30];
		}

		vfunc_allocate(container, box) {
			lmVfuncHits++;
			smokeLog('E lm vfunc_allocate hit=' + lmVfuncHits);
			container.set_allocation(box);
			const cbs = postE.splice(0);
			cbs.forEach(cb => cb());
		}
	});
	const ActorE = GObject.registerClass(
	class ActorE extends St.Widget {
		vfunc_allocate(box) {
			actorVfuncHits++;
			smokeLog('E actor vfunc_allocate hit=' + actorVfuncHits
				+ ' box=' + box.get_width() + 'x' + box.get_height());
			/* Stock: layout manager allocates when present. */
			const glm = this.layout_manager;
			if (glm)
				glm.allocate(this, box);
			else
				this.set_allocation(box);
		}
	});
	const lmE = new LmE();
	const actorE = new ActorE({
		name: 'startup-allocate-smoke-E',
		reactive: true,
	});
	actorE.set_size(80, 30);
	actorE.layout_manager = lmE;
	stage.add_child(actorE);
	actorE.show();

	let resolvedE = false;
	postE.push(() => {
		resolvedE = true;
		smokeLog('E callback resolved');
	});
	smokeLog('E queue_relayout on Actor+LM with vfunc_allocate');
	actorE.queue_relayout();
	waitMs(WAIT_MS);
	smokeLog('E after ' + WAIT_MS + 'ms resolvedE=' + resolvedE
		+ ' actorVfuncHits=' + actorVfuncHits
		+ ' lmVfuncHits=' + lmVfuncHits);
	if (lmVfuncHits < 1)
		smokeLog('FAIL E queue_relayout-no-lm-allocate');
	else if (!resolvedE)
		smokeLog('FAIL E lm-ran-callback-missed');
	else
		smokeLog('E PASS queue_relayout→lm allocate'
			+ (actorVfuncHits > 0 ? '+actor vfunc' : ' (hook→lm)'));

	smokeLog('done');
}

main();
