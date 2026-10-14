/**
 * The 14:40 hang, without the overview. Ease a mapped actor for 250ms,
 * stay inside this turn for 400ms, then read scale-x again.
 *
 * Pass: `scale-transition-gap-smoke: ok`
 * Fail: `scale-transition-gap-smoke: miss <reason>`
 *
 *   GI_META_SMOKE=scale-transition-gap-smoke GSR_WESTON_PIXMAN=1 \
 *     ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Clutter = '16';
imports.gi.versions.Shell = '16';

const { GLib, Clutter, Shell } = imports.gi;

import 'resource:///org/gnome/shell/ui/environment.js';

const SMOKE = 'scale-transition-gap-smoke';

/**
 * @param {string} message
 */
function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function finish(error) {
	if (error != null)
		smokeLog('miss ' + error.message);
	else
		smokeLog('ok');
	global.context.terminate();
}

imports._promiseNative.setMainLoopHook(() => {
	GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
		try {
			const stage = Shell.Global.get().get_stage();
			if (stage == null)
				throw new Error('miss stage');
			const actor = new Clutter.Actor();
			actor.set_size(80, 80);
			stage.add_child(actor);
			actor.show();
			if (!actor.mapped)
				throw new Error('not-mapped');
			actor.save_easing_state();
			/* St.Settings.enable-animations is not writable. dnd.js
			 * omits animationRequired; this forces the 250ms the
			 * 14:40 log actually ran. */
			actor.set_easing_duration(250, {animationRequired: true});
			const duration = actor.get_easing_duration();
			actor.set_scale(0.5, 0.5);
			actor.restore_easing_state();
			const first = actor.get_transition('scale-x');
			if (first == null)
				throw new Error('no-timeline duration=' + duration);
			const end = GLib.get_monotonic_time() + 400 * 1000;
			while (GLib.get_monotonic_time() < end) {}
			const second = actor.get_transition('scale-x');
			if (second == null)
				throw new Error('transition-gone duration=' + duration);
			GLib.timeout_add(GLib.PRIORITY_DEFAULT, 400, () => {
				try {
					const scale = actor.scale_x;
					if (Math.abs(scale - 0.5) > 0.05)
						throw new Error('scale-stuck scale=' + scale);
					finish(null);
				} catch (e) {
					finish(e);
				}
				return GLib.SOURCE_REMOVE;
			});
		} catch (e) {
			finish(e);
		}
		return GLib.SOURCE_REMOVE;
	});
	global.context.run_main_loop();
});
