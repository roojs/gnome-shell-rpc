// Phase 0.7.3 A3: Shell.Global after _shell_global_init + attach_rpc_display.
imports.gi.versions.Shell = '16';
imports.gi.versions.Meta = '16';
imports.gi.versions.Clutter = '16';

const Shell = imports.gi.Shell;
const Meta = imports.gi.Meta;
const Clutter = imports.gi.Clutter;

const global = Shell.Global.get();
if (!global) {
	throw new Error('Shell.Global.get() returned null');
}

const display = global.get_display();
const stage = global.get_stage();
const backend = global.get_backend();

print(`shell-global-smoke: Global=${typeof global}`);
print(`shell-global-smoke: display=${display} stage=${stage} backend=${backend}`);
print(`shell-global-smoke: Clutter.Actor=${typeof Clutter.Actor}`);
print('shell-global-smoke: ok');
