imports.gi.versions.LaterCallbackHold = '1.0';

const {GLib} = imports.gi;
const Hold = imports.gi.LaterCallbackHold;

// Outer Later.add is still on the stack when the inner Later.add runs.
// GJS 1.82 CallbackIn keeps the ffi closure on the shared arg cache, so the
// outer return unrefs the inner trampoline. poke() then calls that callback.
const guard = parseInt(GLib.getenv('LATER_GUARD') || '0', 10);
const nest = parseInt(GLib.getenv('LATER_NEST') || '1', 10);

const later = new Hold.Later();
later.set_guard(guard);
later.set_during_nest_limit(nest);
let phase = 0;
later.set_during_add(() => {
	phase += 1;
	if (phase === 1 && nest >= 2) {
		let midId = 0;
		midId = later.add(() => {
			if (guard === 4)
				later.remove(midId);
			printerr('mid');
			return GLib.SOURCE_REMOVE;
		});
	} else {
		let innerId = 0;
		innerId = later.add(() => {
			if (guard === 4)
				later.remove(innerId);
			printerr('inner');
			return GLib.SOURCE_REMOVE;
		});
	}
	return GLib.SOURCE_REMOVE;
});
let outerId = 0;
outerId = later.add(() => {
	if (guard === 4)
		later.remove(outerId);
	printerr('outer');
	return GLib.SOURCE_REMOVE;
});
if (guard === 2) {
	const ctx = GLib.MainContext.default();
	for (let i = 0; i < 10 && ctx.pending(); i++)
		ctx.iteration(true);
}
printerr('poke');
later.poke();
printerr('PASS later-callback-nested-add live=' + Hold.Later.live_closures());
