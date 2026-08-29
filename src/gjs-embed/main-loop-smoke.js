/**
 * Phase 0.7.3 A4: client GLib loop via Meta.Context.run_main_loop
 * (not mutter's compositor loop). Idle-quit through terminate_with_error.
 */
imports.gi.versions.Shell = '16';
imports.gi.versions.Meta = '16';

const Shell = imports.gi.Shell;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;

const global = Shell.Global.get();
if (!global) {
	throw new Error('Shell.Global.get() returned null');
}

const ctx = global.context;
if (!ctx || typeof ctx.run_main_loop !== 'function') {
	throw new Error('global.context.run_main_loop is not a function');
}
if (typeof ctx.terminate_with_error !== 'function') {
	throw new Error('global.context.terminate_with_error is not a function');
}

print('main-loop-smoke: entering run_main_loop');
GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
	print('main-loop-smoke: quitting via terminate_with_error');
	const error = new GLib.Error(
		Gio.IOErrorEnum,
		Gio.IOErrorEnum.FAILED,
		'main-loop-smoke done');
	ctx.terminate_with_error(error);
	return GLib.SOURCE_REMOVE;
});

ctx.run_main_loop();
print('main-loop-smoke: ok');
