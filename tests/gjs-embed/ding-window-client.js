#!/usr/bin/env gjs
/**
 * One Gtk window for ding-new-subprocess. No extension bus.
 */
imports.gi.versions.Gtk = '3.0';
const { Gio, GLib, Gtk } = imports.gi;

function note(message) {
	try {
		const file = Gio.File.new_for_path('/tmp/ding-window-client.log');
		const stream = file.append_to(Gio.FileCreateFlags.NONE, null);
		stream.write_all(message + '\n', null);
		stream.close(null);
	} catch (e) {
	}
}

note('start');
Gtk.init(null);
note('init');
const window = new Gtk.Window({ title: 'Probe Window' });
window.set_default_size(1280, 800);
window.set_size_request(1280, 800);
window.maximize();
window.show_all();
note('shown');
GLib.timeout_add(GLib.PRIORITY_DEFAULT, 8000, () => {
	Gtk.main_quit();
	return GLib.SOURCE_REMOVE;
});
Gtk.main();
note('quit');
