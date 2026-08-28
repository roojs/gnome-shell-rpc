// Phase 4: prove St loads with client typelibs + libmutter-rpc Meta.
imports.gi.versions.St = '16';
imports.gi.versions.Meta = '16';

const St = imports.gi.St;
const Meta = imports.gi.Meta;

print(`shell-st-smoke: St=${typeof St} Meta=${typeof Meta}`);
print('shell-st-smoke: ok');
