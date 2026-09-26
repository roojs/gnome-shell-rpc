imports.gi.versions.LaterCallbackHold = '1.0';

const {GLib} = imports.gi;
const Hold = imports.gi.LaterCallbackHold;

// Outer Later.add is still on the stack when the inner Later.add runs.
// GJS 1.82 CallbackIn keeps the ffi closure on the shared arg cache, so the
// outer return unrefs the inner trampoline. poke() then calls that callback.
const later = new Hold.Later();
later.set_during_add(() => {
	later.add(() => {
		printerr('inner');
		return GLib.SOURCE_REMOVE;
	});
	return GLib.SOURCE_REMOVE;
});
later.add(() => {
	printerr('outer');
	return GLib.SOURCE_REMOVE;
});
printerr('poke');
later.poke();
printerr('PASS later-callback-nested-add');
