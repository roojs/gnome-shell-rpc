/**
 * Real RPC lease, no shell chrome.
 *
 * Exact St.Viewport is a scroll child and receives the scroll box.
 * A GJS St.Viewport subclass is leased as St.Widget, so set_child
 * rejects it and vfunc_allocate does not run.
 *
 *   GSR_WESTON_SOCKET=wayland-gsr-viewpeer \
 *   GSR_MUTTER_WAYLAND_DISPLAY=wayland-mutter-viewpeer \
 *   GI_META_SMOKE=viewport-scroll-child-smoke GSR_WESTON_PIXMAN=1 \
 *   ./scripts/agent-nested-smoke-prove.sh
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const {GObject, Shell, St, Clutter} = imports.gi;

const SMOKE = 'viewport-scroll-child-smoke';

function smokeLog(message) {
	log(SMOKE + ': ' + message);
}

function serverBox(actor) {
	try {
		const b = actor.get_allocation_box();
		const [w, h] = b.get_size();
		return b.x1 + ',' + b.y1 + ' ' + w + 'x' + h;
	} catch (e) {
		return 'err';
	}
}

function place(stage, child) {
	const scroll = new St.ScrollView({
		width: 800,
		height: 315,
	});
	let assign = 'ok';
	try {
		scroll.child = child;
	} catch (e) {
		assign = 'reject';
	}
	stage.add_child(scroll);
	scroll.show();
	try {
		const box = new Clutter.ActorBox();
		box.init_rect(0, 0, 800, 315);
		scroll.allocate(box);
	} catch (e) {
		assign += ' allocate-threw';
	}
	let linked = 'null';
	try {
		linked = scroll.child == null ? 'null' : 'set';
	} catch (e) {
		linked = 'err';
	}
	return 'assign=' + assign
		+ ' child=' + linked
		+ ' children=' + scroll.get_n_children()
		+ ' box=' + serverBox(child);
}

function main() {
	const stage = Shell.Global.get().get_stage();
	if (stage == null)
		throw new Error(SMOKE + ': stage is null');

	const widget = new St.Widget({
		x_expand: true,
		y_expand: true,
	});
	smokeLog('widget ' + place(stage, widget));

	const exact = new St.Viewport({
		x_expand: true,
		y_expand: true,
	});
	smokeLog('exact ' + place(stage, exact));

	let hits = 0;
	const Peer = GObject.registerClass(
	class Peer extends St.Viewport {
		vfunc_allocate(box) {
			hits++;
			const [w, h] = box.get_size();
			smokeLog('subclass vfunc ' + w + 'x' + h);
			super.vfunc_allocate(box);
		}
	});
	const peer = new Peer({
		x_expand: true,
		y_expand: true,
	});
	smokeLog('subclass ' + place(stage, peer) + ' hits=' + hits);

	const exactBox = exact.get_allocation_box();
	const [exactW, exactH] = exactBox.get_size();
	const peerBox = peer.get_allocation_box();
	const [peerW, peerH] = peerBox.get_size();
	if (exactW < 100 || exactH < 100)
		smokeLog('miss exact');
	else if (hits < 1 || peerW < 100 || peerH < 100)
		smokeLog('miss subclass');
	else
		smokeLog('ok');
	const ctx = Shell.Global.get().context;
	if (ctx != null)
		ctx.terminate();
}

main();
