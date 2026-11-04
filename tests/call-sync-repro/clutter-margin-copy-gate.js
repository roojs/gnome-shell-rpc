imports.gi.versions.Clutter = ARGV[0];
const Clutter = imports.gi.Clutter;

const margin = new Clutter.Margin();
margin.copy();
print('clutter-margin-copy: ok');
