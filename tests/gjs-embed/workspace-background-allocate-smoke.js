/**
 * FAIL smoke — stock Shell.WorkspaceBackground.allocate sizes the first
 * child (_bin) and the first grandchild (_backgroundGroup) so the
 * wallpaper actor gets a real box. Our owned type only held construct
 * props; grandchild stayed 0×0 (overview pane empty).
 *
 * Stock C: vendor/gnome-shell/src/shell-workspace-background.c
 *   allocate(self) → first_child(content_box) → first_child(offset box)
 *
 *   GI_META_SMOKE=workspace-background-allocate-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Prove-only — does not patch stubs/Helpers.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GLib, Shell, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'workspace-background-allocate-smoke';
const WANT_W = 800;
const WANT_H = 400;

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
		throw new Error('workspace-background-allocate-smoke: stage is null');
	}

	const bg = new Shell.WorkspaceBackground({
		monitor_index: 0,
		x_expand: true,
		y_expand: true,
	});
	const bin = new Clutter.Actor({name: 'ws-bg-bin'});
	const inner = new Clutter.Actor({
		name: 'ws-bg-inner',
		x_expand: true,
		y_expand: true,
	});
	bin.add_child(inner);
	bg.add_child(bin);
	stage.add_child(bg);
	bg.show();

	const box = new Clutter.ActorBox();
	box.init_rect(0, 0, WANT_W, WANT_H);
	bg.allocate(box);

	const [bw, bh] = bin.get_size();
	const [iw, ih] = inner.get_size();
	let binBox = 'n/a';
	let innerBox = 'n/a';
	try {
		const b = bin.get_allocation_box();
		binBox = `${b.get_width()}x${b.get_height()}`;
	} catch (e) {
		binBox = `err:${e}`;
	}
	try {
		const b = inner.get_allocation_box();
		innerBox = `${b.get_width()}x${b.get_height()}`;
	} catch (e) {
		innerBox = `err:${e}`;
	}
	smokeLog(`after allocate bin=${bw}x${bh} box=${binBox} inner=${iw}x${ih} box=${innerBox}`);

	if (!(iw > 8 && ih > 8)) {
		smokeLog(`FAIL grandchild-unallocated inner=${iw}x${ih} (want >8x8 in ${WANT_W}x${WANT_H})`);
		smokeLog('done');
		return;
	}
	smokeLog('PASS');
	smokeLog('done');
}

main();
