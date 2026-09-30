/**
 * Meta.Background construct prop + GObject subclass (main.js wallpaper path).
 */
imports.gi.versions.Meta = '16';
imports.gi.versions.Shell = '16';

const Meta = imports.gi.Meta;
const GObject = imports.gi.GObject;
const Shell = imports.gi.Shell;

const display = Shell.Global.get().get_display();
print('bg-subclass-smoke: construct Background');
const bg = new Meta.Background({meta_display: display});
print(`bg-subclass-smoke: bg=${bg}`);

print('bg-subclass-smoke: registerClass subclass');
const Sub = GObject.registerClass(
class Sub extends Meta.Background {
    _init(params) {
        super._init({meta_display: params.meta_display});
    }
});
const sub = new Sub({meta_display: display});
print(`bg-subclass-smoke: sub=${sub}`);
print('bg-subclass-smoke: ok');
