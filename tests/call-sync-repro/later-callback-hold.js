imports.gi.versions.LaterCallbackHold = '1.0';

const {GObject, GLib} = imports.gi;
const System = imports.system;
const Hold = imports.gi.LaterCallbackHold;

let saw = false;
const Obj = GObject.registerClass(class Obj extends GObject.Object {
	tick() {
		saw = true;
		return GLib.SOURCE_REMOVE;
	}
});

const holder = new Hold.Holder();
let obj = new Obj();
holder.store(obj.tick.bind(obj));
obj.run_dispose();
obj = null;
System.gc();

holder.fire();
if (!saw)
	throw new Error('FAIL later-callback-hold: disposed callback was not called');
print('PASS later-callback-hold');
