/**
 * Reproduce the MessageView constructor values without importing main.js.
 *
 *   GI_META_SMOKE=message-view-construct-smoke GSR_NESTED_TIMEOUT=10 \
 *     ./scripts/weston-gsr-prove.sh
 */

imports.gi.versions.Shell = '16';
imports.gi.versions.Clutter = '16';

const {GObject, GLib, Shell, Clutter} = imports.gi;
const SMOKE = 'message-view-construct-smoke';

function smokeLog(message) {
	log(`${SMOKE}: ${message}`);
}

const MessageViewLayout = GObject.registerClass(
class MessageViewLayout extends Clutter.LayoutManager {
	constructor(overlay) {
		smokeLog('layout before super');
		super();
		smokeLog('layout after super');
		this._overlay = overlay;
	}
});

const FadeEffect = GObject.registerClass(
class FadeEffect extends Shell.GLSLEffect {
	constructor(params = {}) {
		smokeLog('effect before super');
		super(params);
		smokeLog('effect after super');
	}

	vfunc_build_pipeline() {
		smokeLog('effect build_pipeline');
	}
});

function main() {
	smokeLog('overlay before');
	const overlay = new Clutter.Actor({
		reactive: true,
		name: 'overlay',
		visible: false,
	});
	smokeLog('overlay after');

	smokeLog('layout before new');
	const layout = new MessageViewLayout(overlay);
	smokeLog(`layout after new ${layout.constructor.name}`);

	smokeLog('base effect before new');
	const baseEffect = new Shell.GLSLEffect({name: 'base-highlight'});
	smokeLog(`base effect after new ${baseEffect.constructor.name}`);

	smokeLog('effect before new');
	const effect = new FadeEffect({name: 'highlight'});
	smokeLog(`effect after new ${effect.constructor.name}`);
	smokeLog('ok');

	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
