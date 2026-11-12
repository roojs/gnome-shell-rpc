#!/usr/bin/env gjs
/**
 * One Gtk window for ding-new-subprocess. No extension bus.
 */
imports.gi.versions.Gtk = '3.0';
const { GLib, Gtk } = imports.gi;

Gtk.init(null);
const window = new Gtk.Window({ title: 'Desktop Icons 1' });
window.set_default_size(320, 200);
window.show_all();
GLib.timeout_add(GLib.PRIORITY_DEFAULT, 8000, () => {
	Gtk.main_quit();
	return GLib.SOURCE_REMOVE;
});
Gtk.main();
