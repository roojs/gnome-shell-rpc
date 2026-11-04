/**
 * Shell 50 panel.js and searchController.js call
 * ClickGesture.get_point_event(0) from recognize / may-recognize.
 * Guest mutter 18 asserts when sequences are empty and the client
 * returns null. Run against stock mutter-18 typelib (no GSR preload).
 * API 16 has no ClickGesture.
 *
 *   meson test -C build click-gesture-point-event --print-errorlogs
 */
imports.gi.versions.Clutter = ARGV[0];
const {Clutter} = imports.gi;

const gesture = new Clutter.ClickGesture({
	recognize_on_press: true,
});
let ev = null;
try {
	ev = gesture.get_point_event(0);
} catch (e) {
	print('click-gesture-point-event: miss threw ' + e);
	throw e;
}
if (ev == null) {
	print('click-gesture-point-event: miss null');
	throw new Error('miss null');
}
print('click-gesture-point-event: ok');
