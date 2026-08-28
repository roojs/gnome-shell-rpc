// Phase 0.7.1 / 4: prove Shell + St load with client typelibs.
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Meta = '16';

const Shell = imports.gi.Shell;
const St = imports.gi.St;
const Meta = imports.gi.Meta;

print(`shell-import-smoke: Shell=${typeof Shell} St=${typeof St} Meta=${typeof Meta}`);
print('shell-import-smoke: ok');
