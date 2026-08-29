/**
 * Phase 0.7.3 A6: Gvc from distro pkglibdir; Shell/St/Meta still load.
 */
imports.gi.versions.Gvc = '1.0';
imports.gi.versions.Shell = '16';
imports.gi.versions.St = '16';
imports.gi.versions.Meta = '16';

const Gvc = imports.gi.Gvc;
const Shell = imports.gi.Shell;
const St = imports.gi.St;
const Meta = imports.gi.Meta;

if (typeof Gvc.MixerControl !== 'function') {
	throw new Error('Gvc.MixerControl missing — pkglibdir not on LD_LIBRARY_PATH?');
}

print(`gvc-smoke: Shell=${typeof Shell} St=${typeof St} Meta=${typeof Meta} Gvc.MixerControl=${typeof Gvc.MixerControl}`);
print('gvc-smoke: ok');
