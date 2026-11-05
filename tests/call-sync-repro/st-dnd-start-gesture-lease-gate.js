imports.gi.versions.St = ARGV[0];
const {GLib, St} = imports.gi;

let why = '';
GLib.log_set_handler(null,
	GLib.LogLevelFlags.LEVEL_CRITICAL | GLib.LogLevelFlags.LEVEL_WARNING,
	(domain, flags, message) => {
		if (message.indexOf('no rpc_lid on StDndStartGesture') !== -1)
			why = 'no rpc_lid';
		if (message.indexOf('Gsr-St-DndStartGesture.create') !== -1)
			why = 'create failed';
	});

const gesture = new St.DndStartGesture({
	manual_mode: false,
	timeout_threshold: 0,
});
void gesture;

if (why !== '') {
	print('st-dnd-start-gesture-lease: miss ' + why);
	throw new Error('miss ' + why);
}
print('st-dnd-start-gesture-lease: ok');
