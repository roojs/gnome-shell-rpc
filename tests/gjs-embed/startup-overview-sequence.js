/**
 * Record the pictures painted during the real startup animation.
 *
 * A before-update while the overview is visible is a frame of that
 * state. The adjustment cache and the opacity cache are updated from
 * notify, so the frame handler does not start another call.
 *
 * Pass: the first solid window picker is after opacity has been 0.
 * Fail: a solid window picker, or a full-screen workspace, is painted
 * while opacity is still up.
 *
 *   GSR_NESTED_TIMEOUT=40 \
 *     GI_META_SMOKE=startup-overview-sequence/ui/init \
 *     ./scripts/weston-gsr-prove.sh
 */

import GLib from 'gi://GLib';
import Shell from 'gi://Shell';

import 'resource:///org/gnome/shell/ui/environment.js';

const SMOKE = 'startup-overview-sequence/ui/init';
const hideBeforeShow = GLib.getenv('GI_META_SMOKE_CMD') === 'hide-before-show';

const state = {
	overview: false,
	value: 1,
	opacity: 255,
	samples: [],
	finished: false,
	startupDone: false,
	finishQueued: false,
	readError: '',
};

function smokeLog(message) {
	log(`${SMOKE}: ${message}`);
}

function picture(sample) {
	if (!sample.overview)
		return 'desktop';
	if (sample.opacity <= 1)
		return 'clear';
	if (sample.value <= 0.05)
		return 'desktop';
	if (sample.value >= 0.9 && sample.opacity >= 200)
		return 'overview';
	return 'move';
}

function rememberFrame() {
	if (state.finished)
		return;
	const sample = {
		overview: state.overview,
		value: state.value,
		opacity: state.opacity,
		frames: 1,
	};
	const last = state.samples[state.samples.length - 1];
	if (last
		&& last.overview === sample.overview
		&& last.value === sample.value
		&& last.opacity === sample.opacity) {
		last.frames++;
	} else {
		state.samples.push(sample);
	}
	if (state.finishQueued || !state.startupDone)
		return;
	if (!(state.overview && state.value >= 0.9 && state.opacity >= 200))
		return;
	state.finishQueued = true;
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		finish();
		return GLib.SOURCE_REMOVE;
	});
}

function finish() {
	if (state.finished)
		return;
	state.finished = true;

	if (state.controls) {
		try {
			state.opacity = state.controls.opacity;
			state.value = state.controls._stateAdjustment.value;
			state.samples.push({
				overview: state.overview,
				value: state.value,
				opacity: state.opacity,
				frames: 0,
			});
		} catch (e) {
			state.readError = `${e}`;
		}
	}

	let sawClear = false;
	let earlyOverview = false;
	let earlyDesktop = false;
	for (const sample of state.samples) {
		if (sample.overview && sample.opacity <= 1)
			sawClear = true;
		const solidPicker = sample.overview
			&& sample.value >= 0.9
			&& sample.opacity >= 200;
		const fullWorkspace = sample.overview
			&& sample.value <= 0.05
			&& sample.opacity >= 200;
		if (!sawClear && solidPicker)
			earlyOverview = true;
		if (!sawClear && fullWorkspace)
			earlyDesktop = true;
	}

	const compressed = [];
	for (const sample of state.samples) {
		const label = picture(sample);
		if (compressed[compressed.length - 1] !== label)
			compressed.push(label);
	}
	const trace = state.samples.map(sample =>
		`${picture(sample)}@ov=${sample.overview ? 1 : 0}`
		+ ` v=${sample.value.toFixed(2)}`
		+ ` o=${Math.round(sample.opacity)} n=${sample.frames}`
	).join(' | ');
	const ended = state.samples.some(sample =>
		sample.overview && sample.value >= 0.9 && sample.opacity >= 200);
	let verdict = 'ok';
	if (state.readError)
		verdict = `miss read ${state.readError}`;
	else if (earlyOverview || earlyDesktop)
		verdict = 'miss';
	else if (!ended)
		verdict = 'miss no-overview';
	smokeLog(`${verdict} ${compressed.join(',')}`);
	smokeLog(`samples ${trace}`);
	Shell.Global.get().context.terminate();
}

function install(Layout, Overview, OverviewControls) {
	const layoutProto = Layout.LayoutManager.prototype;
	const origShow = layoutProto.showOverview;
	layoutProto.showOverview = function () {
		if (hideBeforeShow && state.controls) {
			state.controls.save_easing_state();
			state.controls.set_easing_duration(0);
			state.controls.opacity = 0;
			state.controls.restore_easing_state();
			smokeLog(`hide-set o=${state.opacity}`);
		}
		state.overview = true;
		const result = origShow.apply(this, arguments);
		smokeLog(`show-return v=${state.value} o=${state.opacity} trial=${hideBeforeShow}`);
		return result;
	};
	const origHide = layoutProto.hideOverview;
	layoutProto.hideOverview = function () {
		state.overview = false;
		return origHide.apply(this, arguments);
	};

	const controlsProto = OverviewControls.ControlsManager.prototype;
	const origInit = controlsProto._init;
	controlsProto._init = function () {
		const result = origInit.apply(this, arguments);
		state.controls = this;
		try {
			state.value = this._stateAdjustment.value;
			state.opacity = this.opacity;
		} catch (e) {
			state.readError = `${e}`;
		}
		this._stateAdjustment.connect('notify::value', () => {
			try {
				state.value = this._stateAdjustment.value;
			} catch (e) {
				state.readError = `${e}`;
			}
		});
		this.connect('notify::opacity', () => {
			try {
				state.opacity = this.opacity;
			} catch (e) {
				state.readError = `${e}`;
			}
		});
		smokeLog(`controls-init v=${state.value} o=${state.opacity}`);
		return result;
	};

	const overviewProto = Overview.Overview.prototype;
	const origRun = overviewProto.runStartupAnimation;
	overviewProto.runStartupAnimation = async function () {
		try {
			await origRun.apply(this, arguments);
		} finally {
			state.startupDone = true;
		}
	};
}

async function run() {
	const Layout = await import('resource:///org/gnome/shell/ui/layout.js');
	const Overview = await import('resource:///org/gnome/shell/ui/overview.js');
	const OverviewControls = await import('resource:///org/gnome/shell/ui/overviewControls.js');
	install(Layout, Overview, OverviewControls);
	const main = await import('resource:///org/gnome/shell/ui/main.js');
	await main.start();
}

imports._promiseNative.setMainLoopHook(() => {
	try {
		global.stage.connect('before-update', () => {
			rememberFrame();
		});
	} catch (e) {
		state.readError = `before-update ${e}`;
	}
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 25000, () => {
		finish();
		return GLib.SOURCE_REMOVE;
	});
	run().catch(e => {
		state.readError = `${e}`;
		finish();
	});
	Shell.Global.get().context.run_main_loop();
});
