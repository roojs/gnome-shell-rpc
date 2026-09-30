/**
 * FAIL smoke — SIGSEGV in GJS around clutter_actor_allocate (boot crash).
 *
 *   GI_META_SMOKE=allocate-segv-smoke GSR_WESTON_MODE=prove \
 *     ./scripts/weston-gsr-session.sh
 *
 * Pin (2026-09-16): full chrome nest → client exit 139; libSegFault:
 *   libgjs (GObject marshal) ← ffi ← clutter_actor_allocate+0x71 (stub)
 * Simple St.Widget.allocate(box) survives. Next: GJS subclass vfunc + chain-up.
 */

imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Clutter = '16';

const { GObject, GLib, Shell, St, Clutter } = imports.gi;

const SMOKE_DOMAIN = 'allocate-segv-smoke';
function smokeLog(m) { log(SMOKE_DOMAIN + ': ' + m); }

function main() {
	const stage = Shell.Global.get().get_stage();

	let hits = 0;
	const Sub = GObject.registerClass(
	class AllocateSegvSub extends St.Widget {
		vfunc_allocate(box) {
			hits++;
			smokeLog('vfunc_allocate hit=' + hits
				+ ' box=' + box.get_x() + ',' + box.get_y()
				+ ' ' + box.get_width() + 'x' + box.get_height());
			/* Stock chrome pattern: chain up / call public allocate on self
			 * and children. This is the re-enter corridor. */
			try {
				smokeLog('chain: Clutter.Actor.prototype.allocate');
				Clutter.Actor.prototype.allocate.call(this, box);
				smokeLog('chain: prototype.allocate returned');
			} catch (e) {
				smokeLog('chain threw ' + e);
				throw e;
			}
		}
	});

	const actor = new Sub({ name: 'allocate-segv-sub', reactive: true });
	actor.set_size(40, 20);
	stage.add_child(actor);
	actor.show();

	const box = new Clutter.ActorBox();
	box.init_rect(0, 0, 40, 20);
	smokeLog('calling actor.allocate (public/GI)');
	actor.allocate(box);
	smokeLog('actor.allocate returned hits=' + hits);

	smokeLog('queue_relayout + wait');
	actor.queue_relayout();
	const loop = new GLib.MainLoop(null, false);
	GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
		smokeLog('after wait hits=' + hits);
		if (hits < 1)
			smokeLog('FAIL vfunc never ran');
		else
			smokeLog('PASS survived vfunc+chain hits=' + hits);
		smokeLog('done');
		loop.quit();
		return GLib.SOURCE_REMOVE;
	});
	loop.run();
}

main();
