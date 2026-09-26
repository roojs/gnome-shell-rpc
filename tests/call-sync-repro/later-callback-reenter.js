imports.gi.versions.LaterCallbackHold = '1.0';

const {GObject, GLib} = imports.gi;
const System = imports.system;
const Hold = imports.gi.LaterCallbackHold;

const Obj = GObject.registerClass(class Obj extends GObject.Object {
	tick() {
		printerr('tick');
		return GLib.SOURCE_REMOVE;
	}
});

// Same order as layout.js _updateRegions inside a before-redraw that
// arrives while another callback is still running: remove self, dispose
// the bound object, then run the queue again.
const later = new Hold.Later();
const obj = new Obj();
let id1 = 0;
id1 = later.add(() => {
	printerr('cb1');
	later.remove(id1);
	obj.run_dispose();
	System.gc();
	later.poke();
	return GLib.SOURCE_REMOVE;
});
later.add(obj.tick.bind(obj));
printerr('outer poke');
later.poke();
printerr('nested done');

// Drop the JS wrapper while C still holds the Later, then run the callback.
let parked = new Hold.Later();
parked.add(() => {
	printerr('after wrapper gc');
	return GLib.SOURCE_REMOVE;
});
parked.pin();
parked = null;
System.gc();
printerr('pinned poke');
Hold.Later.get_pinned().poke();

// Nested poke of the same callback. The inner call removes it while the
// outer invocation is still on the stack.
printerr('reenter same');
const same = new Hold.Later();
let sameId = 0;
let depth = 0;
sameId = same.add(() => {
	depth += 1;
	printerr('same depth ' + depth);
	if (depth === 1) {
		same.poke();
		return GLib.SOURCE_REMOVE;
	}
	same.remove(sameId);
	return GLib.SOURCE_REMOVE;
});
same.poke();
printerr('same done');

// Dispose from inside the callback, and poke again from dispose. GJS treats
// a callback during dispose as illegal for notified closures.
printerr('dispose reenter');
const Host = GObject.registerClass(class Host extends GObject.Object {
	vfunc_dispose() {
		if (this._poking)
			return;
		this._poking = true;
		printerr('vfunc_dispose');
		if (this.later)
			this.later.poke();
		super.vfunc_dispose();
	}
});
const host = new Host();
const box = new Hold.Later();
host.later = box;
let hostId = 0;
hostId = box.add(() => {
	printerr('dispose-cb');
	if (!host._did) {
		host._did = true;
		host.run_dispose();
	}
	box.remove(hostId);
	return GLib.SOURCE_REMOVE;
});
box.poke();
printerr('PASS later-callback-reenter');
