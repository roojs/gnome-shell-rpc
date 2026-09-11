/**
 * Prove Meta GObject.get_property over Gi (GIR props without accessors).
 *
 *   GI_META_SMOKE=property-smoke \
 *     dbus-run-session ./build/src/mutter-rpc --debug --wayland --nested
 */
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';

console.log('property-smoke: start');
const global = Shell.Global.get();
const display = global.get_display();
const ctx = display.get_context();
const backend = ctx.get_backend();
const mm = backend.get_monitor_manager();

console.log('property-smoke: reading night-light-supported');
const night = mm.night_light_supported;
console.log(`property-smoke: night-light-supported=${night}`);

console.log('property-smoke: reading unsafe-mode');
const unsafe = ctx.unsafe_mode;
console.log(`property-smoke: unsafe-mode=${unsafe}`);

console.log('property-smoke: ok');
GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
	ctx.terminate();
	return GLib.SOURCE_REMOVE;
});
