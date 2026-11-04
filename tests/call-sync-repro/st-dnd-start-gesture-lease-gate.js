imports.gi.versions.St = ARGV[0];
const {GLib, St} = imports.gi;

let saw = false;
GLib.log_set_handler(null, GLib.LogLevelFlags.LEVEL_CRITICAL, (domain, flags, message) => {
	if (message.indexOf('no rpc_lid on StDndStartGesture') !== -1)
		saw = true;
});

const gesture = new St.DndStartGesture({
	manual_mode: false,
	timeout_threshold: 0,
});
void gesture;

if (saw) {
	print('st-dnd-start-gesture-lease: miss no rpc_lid');
	throw new Error('miss no rpc_lid');
}
print('st-dnd-start-gesture-lease: ok');
